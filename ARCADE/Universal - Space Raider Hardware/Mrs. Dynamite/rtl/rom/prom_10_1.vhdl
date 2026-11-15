library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity prom_10_1 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(4 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of prom_10_1 is
	type rom is array(0 to  31) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"FF",X"BF",X"3E",X"3F",X"EF",X"FE",X"F6",X"06",X"0F",X"C6",X"CF",X"CE",X"D6",X"E6",X"8F",X"FF",
		X"3F",X"FE",X"C6",X"E6",X"3E",X"B6",X"EF",X"F6",X"BF",X"3F",X"FE",X"06",X"0F",X"F6",X"CF",X"C6"
	);
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
