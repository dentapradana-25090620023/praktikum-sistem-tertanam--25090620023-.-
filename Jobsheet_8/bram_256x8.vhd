----------------------------------------------------------------------------------
-- Jobsheet 8 - Langkah 1
-- bram_256x8.vhd : memori sinkron 256 x 8 bit (di-infer menjadi BRAM)
-- Kunci agar jadi BRAM: baca & tulis di dalam process sinkron clock,
-- dan hasil baca disimpan di register (dout_reg).
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bram_256x8 is
    Port ( clk  : in  STD_LOGIC;
           we   : in  STD_LOGIC;                      -- write enable
           addr : in  STD_LOGIC_VECTOR (7 downto 0);  -- 256 alamat
           din  : in  STD_LOGIC_VECTOR (7 downto 0);
           dout : out STD_LOGIC_VECTOR (7 downto 0) );
end bram_256x8;

architecture Behavioral of bram_256x8 is
    type ram_type is array (0 to 255) of STD_LOGIC_VECTOR(7 downto 0);
    signal ram      : ram_type := (others => (others => '0'));
    signal dout_reg : STD_LOGIC_VECTOR(7 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram(to_integer(unsigned(addr))) <= din;
            end if;
            dout_reg <= ram(to_integer(unsigned(addr)));  -- registered output -> infer BRAM
        end if;
    end process;

    dout <= dout_reg;
end Behavioral;
