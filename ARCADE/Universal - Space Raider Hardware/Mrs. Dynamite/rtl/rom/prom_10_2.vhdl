library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity prom_10_2 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(4 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of prom_10_2 is
	type rom is array(0 to  31) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"00",X"36",X"E9",X"CE",X"00",X"C5",X"36",X"9E",X"00",X"E5",X"CA",X"19",X"00",X"59",X"9B",X"AA",
		X"00",X"49",X"9E",X"1A",X"00",X"92",X"66",X"5E",X"00",X"11",X"C9",X"86",X"00",X"CE",X"EB",X"6D"
	);
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
