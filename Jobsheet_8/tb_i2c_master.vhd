----------------------------------------------------------------------------------
-- Jobsheet 8 - Langkah 4
-- tb_i2c_master.vhd : menguji i2c_master dengan model slave sederhana (alamat 0x4B,
-- sama dengan alamat default Pmod TMP2).
--
-- Skenario:
--   Tes 1 : TULIS 1 byte (pointer register 0x00)  -> harus di-ACK
--   Tes 2 : BACA  1 byte                          -> slave mengirim 0xA5
--   Tes 3 : alamat salah (0x50)                   -> harus NACK (ack_error = '1')
--
-- Jalankan simulasi minimal 1 ms (run 1 ms) agar ketiga transaksi selesai.
-- Amati di waveform: scl, sda, i2c_master/state, i2c_master/phase.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_i2c_master is
end tb_i2c_master;

architecture sim of tb_i2c_master is
    constant SLAVE_ADDR : std_logic_vector(6 downto 0) := "1001011";  -- 0x4B

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal start      : std_logic := '0';
    signal rw         : std_logic := '0';
    signal slave_addr_s : std_logic_vector(6 downto 0) := (others => '0');
    signal data_wr    : std_logic_vector(7 downto 0) := (others => '0');
    signal data_rd    : std_logic_vector(7 downto 0);
    signal busy       : std_logic;
    signal done       : std_logic;
    signal ack_error  : std_logic;
    signal scl        : std_logic;
    signal sda        : std_logic;
    signal sim_done   : boolean := false;
begin
    -- Resistor pull-up pada bus (open-drain)
    scl <= 'H';
    sda <= 'H';

    uut : entity work.i2c_master
        port map (
            clk => clk, rst => rst, start => start, rw => rw,
            slave_addr => slave_addr_s, data_wr => data_wr, data_rd => data_rd,
            busy => busy, done => done, ack_error => ack_error,
            scl => scl, sda => sda
        );

    -- clock 100 MHz
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for 5 ns;
            clk <= '1'; wait for 5 ns;
        end loop;
        wait;
    end process;

    ------------------------------------------------------------------
    -- Model slave I2C (perilaku sederhana, bukan untuk disintesis)
    ------------------------------------------------------------------
    slave : process
        variable sh : std_logic_vector(7 downto 0);
        variable rx : std_logic_vector(7 downto 0);
        constant TX_DATA : std_logic_vector(7 downto 0) := x"A5";
    begin
        sda <= 'Z';
        -- tunggu START: SDA turun saat SCL tinggi
        wait until falling_edge(sda) and to_x01(scl) = '1';

        -- terima 8 bit (7-bit alamat + R/W), sampling di rising edge SCL
        for i in 7 downto 0 loop
            wait until rising_edge(scl);
            sh(i) := to_x01(sda);
        end loop;

        wait until falling_edge(scl);               -- akhir clock ke-8
        if sh(7 downto 1) = SLAVE_ADDR then
            sda <= '0';                             -- ACK pada clock ke-9
            wait until falling_edge(scl);           -- akhir clock ke-9

            if sh(0) = '0' then
                -- Master menulis: terima 1 byte, beri ACK
                sda <= 'Z';
                for i in 7 downto 0 loop
                    wait until rising_edge(scl);
                    rx(i) := to_x01(sda);
                end loop;
                wait until falling_edge(scl);
                sda <= '0';                         -- ACK
                wait until falling_edge(scl);
                sda <= 'Z';
                report "Slave menerima byte = " & integer'image(to_integer(unsigned(rx)));
            else
                -- Master membaca: kirim TX_DATA, MSB dulu
                for i in 7 downto 0 loop
                    if TX_DATA(i) = '0' then sda <= '0'; else sda <= 'Z'; end if;
                    wait until falling_edge(scl);
                end loop;
                sda <= 'Z';                         -- lepas SDA untuk NACK dari master
            end if;
        else
            report "Slave: alamat tidak cocok -> NACK";
        end if;
    end process;

    ------------------------------------------------------------------
    -- Stimulus
    ------------------------------------------------------------------
    stim : process
        procedure transaksi(constant a : in std_logic_vector(6 downto 0);
                            constant r : in std_logic;
                            constant d : in std_logic_vector(7 downto 0)) is
        begin
            slave_addr_s <= a;
            rw           <= r;
            data_wr      <= d;
            wait until rising_edge(clk);
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
            wait until done = '1';
            wait until rising_edge(clk);
        end procedure;
    begin
        rst <= '1';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

        -- Tes 1: tulis pointer register
        report "Tes 1: TULIS 0x00 ke slave 0x4B";
        transaksi(SLAVE_ADDR, '0', x"00");
        assert ack_error = '0' report "Tes 1 GAGAL: slave seharusnya ACK" severity error;

        wait for 20 us;

        -- Tes 2: baca 1 byte
        report "Tes 2: BACA 1 byte dari slave 0x4B";
        transaksi(SLAVE_ADDR, '1', x"00");
        assert ack_error = '0' report "Tes 2 GAGAL: slave seharusnya ACK alamat" severity error;
        assert data_rd = x"A5"
            report "Tes 2 GAGAL: data dibaca " & integer'image(to_integer(unsigned(data_rd))) &
                   ", seharusnya 165 (0xA5)"
            severity error;

        wait for 20 us;

        -- Tes 3: alamat salah
        report "Tes 3: alamat salah 0x50 -> harus NACK";
        transaksi("1010000", '0', x"00");
        assert ack_error = '1' report "Tes 3 GAGAL: seharusnya NACK" severity error;

        report "TESTBENCH I2C SELESAI - jika tidak ada pesan GAGAL, semua tes lulus.";
        sim_done <= true;
        wait;
    end process;
end sim;
