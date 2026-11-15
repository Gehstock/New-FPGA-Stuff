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
		X"FF",X"A6",X"B6",X"DF",X"36",X"CE",X"BE",X"E6",X"0F",X"C6",X"F6",X"3F",X"CF",X"06",X"8F",X"FF",
		X"3F",X"DF",X"96",X"0F",X"F6",X"BE",X"EF",X"0F",X"DF",X"3F",X"0F",X"06",X"C6",X"E6",X"36",X"FE");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
