----------------------------------------------------------------------------------
-- Jobsheet 8 - Tugas 1
-- bram_1024x8.vhd : versi generik dari bram_256x8.
-- ADDR_WIDTH = 10 -> 1024 x 8 bit (sesuai soal).
-- Untuk eksperimen tambahan, ubah ADDR_WIDTH (mis. 12, 14, 15) lalu sintesis ulang
-- dan bandingkan laporan Utilization (kategori Memory / Block RAM Tile).
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bram_1024x8 is
    Generic ( ADDR_WIDTH : integer := 10 );          -- 2**10 = 1024 alamat
    Port ( clk  : in  STD_LOGIC;
           we   : in  STD_LOGIC;
           addr : in  STD_LOGIC_VECTOR (ADDR_WIDTH-1 downto 0);
           din  : in  STD_LOGIC_VECTOR (7 downto 0);
           dout : out STD_LOGIC_VECTOR (7 downto 0) );
end bram_1024x8;

architecture Behavioral of bram_1024x8 is
    type ram_type is array (0 to 2**ADDR_WIDTH - 1) of STD_LOGIC_VECTOR(7 downto 0);
    signal ram      : ram_type := (others => (others => '0'));
    signal dout_reg : STD_LOGIC_VECTOR(7 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram(to_integer(unsigned(addr))) <= din;
            end if;
            dout_reg <= ram(to_integer(unsigned(addr)));
        end if;
    end process;

    dout <= dout_reg;
end Behavioral;
