library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity led_switch_top is
    Port ( sw  : in  STD_LOGIC_VECTOR (15 downto 0);
           led : out STD_LOGIC_VECTOR (15 downto 0));
end led_switch_top;

architecture Behavioral of led_switch_top is
begin
    -- Sakelar sw[0] mengontrol led[0], sw[1] mengontrol led[1], dst hingga sw[15] dan led[15]
    led <= sw;
end Behavioral;