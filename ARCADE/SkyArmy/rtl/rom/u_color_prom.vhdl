library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity u_color_prom is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(4 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of u_color_prom is
	type rom is array(0 to  31) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"00",X"18",X"00",X"99",X"00",X"18",X"7F",X"47",X"00",X"38",X"07",X"18",X"00",X"66",X"3F",X"FF",
		X"00",X"B6",X"99",X"A4",X"00",X"0E",X"37",X"18",X"00",X"CA",X"FD",X"37",X"00",X"3F",X"FF",X"07");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
