library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity prom_tile_m8 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(4 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of prom_tile_m8 is
	type rom is array(0 to  31) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"08",X"7E",X"79",X"7F",X"08",X"7F",X"7F",X"19",X"08",X"7F",X"7F",X"1F",X"08",X"7F",X"7F",X"1E",
		X"00",X"47",X"37",X"66",X"00",X"47",X"77",X"63",X"00",X"47",X"17",X"65",X"80",X"F7",X"F7",X"F2");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
