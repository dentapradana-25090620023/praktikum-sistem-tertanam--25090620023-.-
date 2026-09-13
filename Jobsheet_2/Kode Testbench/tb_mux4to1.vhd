library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_mux4to1 is
-- Testbench entity selalu KOSONG!
end tb_mux4to1;

architecture sim of tb_mux4to1 is
    signal sel_tb : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal in0_tb : STD_LOGIC_VECTOR(3 downto 0) := "0001"; -- Nilai 1
    signal in1_tb : STD_LOGIC_VECTOR(3 downto 0) := "0010"; -- Nilai 2
    signal in2_tb : STD_LOGIC_VECTOR(3 downto 0) := "0100"; -- Nilai 4
    signal in3_tb : STD_LOGIC_VECTOR(3 downto 0) := "1000"; -- Nilai 8
    signal y_tb   : STD_LOGIC_VECTOR(3 downto 0);
begin
    -- Instansiasi Device Under Test (DUT)
    DUT: entity work.mux4to1
        port map (
            sel => sel_tb,
            in0 => in0_tb,
            in1 => in1_tb,
            in2 => in2_tb,
            in3 => in3_tb,
            y   => y_tb
        );

    -- Proses Pemberian Sinyal & Pengujian (Stimulus)
    stim_proc: process
    begin
        -- Skenario 1: sel = "00", y harus bernilai in0 ("0001")
        sel_tb <= "00"; wait for 20 ns;
        assert (y_tb = "0001") report "Error pada sel 00!" severity error;

        -- Skenario 2: sel = "01", y harus bernilai in1 ("0010")
        sel_tb <= "01"; wait for 20 ns;
        assert (y_tb = "0010") report "Error pada sel 01!" severity error;

        -- Skenario 3: sel = "10", y harus bernilai in2 ("0100")
        sel_tb <= "10"; wait for 20 ns;
        assert (y_tb = "0100") report "Error pada sel 10!" severity error;

        -- Skenario 4: sel = "11", y harus bernilai in3 ("1000")
        sel_tb <= "11"; wait for 20 ns;
        assert (y_tb = "1000") report "Error pada sel 11!" severity error;

        wait; -- Hentikan simulasi
    end process;
end sim;