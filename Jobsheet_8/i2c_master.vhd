----------------------------------------------------------------------------------
-- Jobsheet 8 - Langkah 3
-- i2c_master.vhd : kerangka FSM I2C master (transaksi 1 byte: tulis ATAU baca)
--
-- State (sesuai Kode 8.2): S_IDLE, S_START, S_ADDR, S_ADDR_ACK, S_DATA, S_DATA_ACK, S_STOP
--
-- Ide waktu: setiap 1 bit I2C dibagi 4 "fase" (seperempat periode SCL):
--   fase 0 : SCL rendah, SDA diatur ke nilai bit
--   fase 1 : SCL dilepas (naik)
--   fase 2 : SCL tinggi, SDA stabil (slave membaca / master sampling)
--   fase 3 : SCL ditarik rendah (turun), geser bit
-- Karena itu 'tick' dibuat dengan frekuensi 4 x I2C_FREQ (= 400 kHz).
--
-- SCL/SDA open-drain: master hanya boleh menarik ke '0' atau melepas ('Z').
-- Level '1' dibuat oleh resistor pull-up eksternal.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_master is
    Generic (
        CLK_FREQ : integer := 100_000_000;   -- clock Basys 3
        I2C_FREQ : integer := 100_000        -- standard mode
    );
    Port (
        clk        : in    STD_LOGIC;
        rst        : in    STD_LOGIC;
        start      : in    STD_LOGIC;                      -- pulsa 1 clock untuk memulai
        rw         : in    STD_LOGIC;                      -- '0' = tulis, '1' = baca
        slave_addr : in    STD_LOGIC_VECTOR (6 downto 0);
        data_wr    : in    STD_LOGIC_VECTOR (7 downto 0);  -- byte yang dikirim (mode tulis)
        data_rd    : out   STD_LOGIC_VECTOR (7 downto 0);  -- byte yang diterima (mode baca)
        busy       : out   STD_LOGIC;
        done       : out   STD_LOGIC;                      -- pulsa 1 clock saat transaksi selesai
        ack_error  : out   STD_LOGIC;                      -- '1' jika slave NACK
        scl        : inout STD_LOGIC;
        sda        : inout STD_LOGIC
    );
end i2c_master;

architecture Behavioral of i2c_master is
    constant DIV : integer := CLK_FREQ / (I2C_FREQ * 4);   -- 100e6/400e3 = 250

    type i2c_state is (S_IDLE, S_START, S_ADDR, S_ADDR_ACK,
                       S_DATA, S_DATA_ACK, S_STOP);
    signal state : i2c_state := S_IDLE;

    signal cnt     : integer range 0 to DIV-1 := 0;
    signal tick    : std_logic := '0';
    signal phase   : unsigned(1 downto 0) := (others => '0');
    signal bit_cnt : integer range 0 to 7 := 7;
    signal shreg   : std_logic_vector(7 downto 0) := (others => '0');

    signal addr_r  : std_logic_vector(6 downto 0) := (others => '0');
    signal wdata_r : std_logic_vector(7 downto 0) := (others => '0');
    signal rw_r    : std_logic := '0';

    signal scl_low : std_logic := '0';   -- '1' = tarik SCL ke 0, '0' = lepas
    signal sda_low : std_logic := '0';   -- '1' = tarik SDA ke 0, '0' = lepas
    signal sda_in  : std_logic;
    signal ack_err : std_logic := '0';
begin
    -- Driver open-drain
    scl    <= '0' when scl_low = '1' else 'Z';
    sda    <= '0' when sda_low = '1' else 'Z';
    sda_in <= to_x01(sda);               -- 'H' (pull-up) dibaca sebagai '1'

    busy      <= '0' when state = S_IDLE else '1';
    ack_error <= ack_err;

    ------------------------------------------------------------------
    -- Pembangkit tick 400 kHz (aktif hanya saat transaksi berjalan)
    ------------------------------------------------------------------
    tick_gen : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or state = S_IDLE then
                cnt  <= 0;
                tick <= '0';
            elsif cnt = DIV - 1 then
                cnt  <= 0;
                tick <= '1';
            else
                cnt  <= cnt + 1;
                tick <= '0';
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- FSM utama
    ------------------------------------------------------------------
    fsm : process(clk)
    begin
        if rising_edge(clk) then
            done <= '0';

            if rst = '1' then
                state   <= S_IDLE;
                phase   <= (others => '0');
                scl_low <= '0';
                sda_low <= '0';
                ack_err <= '0';
                data_rd <= (others => '0');

            elsif state = S_IDLE then
                if start = '1' then
                    addr_r  <= slave_addr;
                    wdata_r <= data_wr;
                    rw_r    <= rw;
                    ack_err <= '0';
                    phase   <= "00";
                    state   <= S_START;
                end if;

            elsif tick = '1' then
                case state is

                    ------------------------------------------------ START
                    when S_START =>
                        case phase is
                            when "00" => scl_low <= '0'; sda_low <= '0';  -- keduanya tinggi
                            when "01" => sda_low <= '1';                  -- SDA turun saat SCL tinggi = START
                            when "10" => scl_low <= '1';                  -- SCL turun
                            when others =>
                                shreg   <= addr_r & rw_r;                 -- 7-bit alamat + R/W
                                bit_cnt <= 7;
                                state   <= S_ADDR;
                        end case;

                    ------------------------------------------------ KIRIM ALAMAT
                    when S_ADDR =>
                        case phase is
                            when "00" => sda_low <= not shreg(7);         -- bit '1' = lepas, '0' = tarik
                            when "01" => scl_low <= '0';                  -- SCL naik
                            when "10" => null;                            -- SCL tinggi, data stabil
                            when others =>
                                scl_low <= '1';                           -- SCL turun
                                shreg   <= shreg(6 downto 0) & '0';
                                if bit_cnt = 0 then
                                    state <= S_ADDR_ACK;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                end if;
                        end case;

                    ------------------------------------------------ ACK DARI SLAVE (alamat)
                    when S_ADDR_ACK =>
                        case phase is
                            when "00" => sda_low <= '0';                  -- lepas SDA, slave yang drive
                            when "01" => scl_low <= '0';
                            when "10" =>
                                if sda_in = '1' then ack_err <= '1'; end if;  -- NACK
                            when others =>
                                scl_low <= '1';
                                if ack_err = '1' then
                                    state <= S_STOP;                      -- slave tidak menjawab
                                else
                                    shreg   <= wdata_r;
                                    bit_cnt <= 7;
                                    state   <= S_DATA;
                                end if;
                        end case;

                    ------------------------------------------------ DATA (tulis / baca)
                    when S_DATA =>
                        case phase is
                            when "00" =>
                                if rw_r = '0' then
                                    sda_low <= not shreg(7);              -- master mengirim bit
                                else
                                    sda_low <= '0';                       -- master lepas SDA, slave yang kirim
                                end if;
                            when "01" => scl_low <= '0';
                            when "10" =>
                                if rw_r = '1' then
                                    shreg <= shreg(6 downto 0) & sda_in;  -- sampling bit dari slave
                                end if;
                            when others =>
                                scl_low <= '1';
                                if rw_r = '0' then
                                    shreg <= shreg(6 downto 0) & '0';
                                end if;
                                if bit_cnt = 0 then
                                    state <= S_DATA_ACK;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                end if;
                        end case;

                    ------------------------------------------------ ACK/NACK (data)
                    -- Mode tulis : slave memberi ACK, master memeriksa.
                    -- Mode baca  : master memberi NACK (SDA dilepas = '1') karena hanya 1 byte.
                    when S_DATA_ACK =>
                        case phase is
                            when "00" =>
                                sda_low <= '0';
                                data_rd <= shreg;
                            when "01" => scl_low <= '0';
                            when "10" =>
                                if rw_r = '0' and sda_in = '1' then ack_err <= '1'; end if;
                            when others =>
                                scl_low <= '1';
                                state   <= S_STOP;
                        end case;

                    ------------------------------------------------ STOP
                    when S_STOP =>
                        case phase is
                            when "00" => sda_low <= '1';                  -- SDA rendah (SCL masih rendah)
                            when "01" => scl_low <= '0';                  -- SCL naik
                            when "10" => sda_low <= '0';                  -- SDA naik saat SCL tinggi = STOP
                            when others =>
                                state <= S_IDLE;
                                done  <= '1';
                        end case;

                    when others => null;
                end case;

                phase <= phase + 1;   -- 2 bit: setelah "11" otomatis kembali ke "00"
            end if;
        end if;
    end process;
end Behavioral;
