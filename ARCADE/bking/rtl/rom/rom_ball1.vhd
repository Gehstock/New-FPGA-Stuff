library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity rom_ball1 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(6 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of rom_ball1 is
	type rom is array(0 to  127) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"00",X"00",X"00",X"18",X"18",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"08",X"1C",X"08",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"18",X"3C",X"3C",X"18",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"18",X"3C",X"3C",X"3C",X"18",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"18",X"3C",X"7E",X"7E",X"3C",X"18",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"18",X"3C",X"7E",X"7E",X"7E",X"3C",X"18",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"18",X"3C",X"7E",X"7E",X"7E",X"7E",X"3C",X"18",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"09",X"10",X"55",X"B0",X"78",X"3B",X"74",X"A0",X"14",X"10",X"00",X"00",X"00",X"00",X"00",X"00");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
