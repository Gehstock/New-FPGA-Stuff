library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity prom_tile_m9 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(4 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of prom_tile_m9 is
	type rom is array(0 to  31) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"08",X"6E",X"49",X"7F",X"08",X"6E",X"4B",X"79",X"08",X"7E",X"7B",X"29",X"08",X"7A",X"7F",X"7F",
		X"00",X"46",X"33",X"61",X"00",X"46",X"73",X"61",X"00",X"47",X"17",X"61",X"80",X"F6",X"F4",X"F7");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
