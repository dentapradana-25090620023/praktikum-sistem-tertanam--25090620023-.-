----------------------------------------------------------------------------------
-- Jobsheet 8 - Langkah 1 (testbench)
-- Tulis 8 data ke 8 alamat berbeda, lalu baca kembali dan verifikasi dengan assert.
-- Ingat: BRAM sinkron -> data baca baru muncul SETELAH clock edge (latensi 1 clock).
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_bram_256x8 is
end tb_bram_256x8;

architecture sim of tb_bram_256x8 is
    signal clk      : std_logic := '0';
    signal we       : std_logic := '0';
    signal addr     : std_logic_vector(7 downto 0) := (others => '0');
    signal din      : std_logic_vector(7 downto 0) := (others => '0');
    signal dout     : std_logic_vector(7 downto 0);
    signal sim_done : boolean := false;
begin
    uut : entity work.bram_256x8
        port map (clk => clk, we => we, addr => addr, din => din, dout => dout);

    -- clock 100 MHz
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for 5 ns;
            clk <= '1'; wait for 5 ns;
        end loop;
        wait;
    end process;

    stim : process
        variable expected : std_logic_vector(7 downto 0);
    begin
        wait for 20 ns;

        -- FASE TULIS: alamat = i*10, data = 0xA0 + i
        for i in 0 to 7 loop
            addr <= std_logic_vector(to_unsigned(i * 10, 8));
            din  <= std_logic_vector(to_unsigned(16#A0# + i, 8));
            we   <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        we <= '0';

        -- FASE BACA: verifikasi tiap alamat
        for i in 0 to 7 loop
            addr <= std_logic_vector(to_unsigned(i * 10, 8));
            wait until rising_edge(clk);   -- alamat di-latch, dout_reg terisi
            wait for 1 ns;
            expected := std_logic_vector(to_unsigned(16#A0# + i, 8));
            assert dout = expected
                report "GAGAL di alamat " & integer'image(i * 10) &
                       " : dibaca " & integer'image(to_integer(unsigned(dout))) &
                       ", seharusnya " & integer'image(to_integer(unsigned(expected)))
                severity error;
        end loop;

        -- Alamat yang belum pernah ditulis harus berisi 0 (nilai awal)
        addr <= x"FF";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert dout = x"00"
            report "Alamat 255 seharusnya 0 (belum ditulis)" severity error;

        report "TESTBENCH BRAM SELESAI - jika tidak ada pesan GAGAL, semua data benar.";
        sim_done <= true;
        wait;
    end process;
end sim;
