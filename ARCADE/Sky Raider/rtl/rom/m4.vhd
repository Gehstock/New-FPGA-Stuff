library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity m4 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(3 downto 0)
);
end entity;

architecture prom of m4 is
	type rom is array(0 to  255) of std_logic_vector(3 downto 0);
	signal rom_data: rom := (
		X"4",X"0",X"4",X"0",X"3",X"1",X"3",X"7",X"1",X"D",X"0",X"C",X"0",X"F",X"0",X"F",
		X"1",X"E",X"1",X"E",X"1",X"E",X"3",X"C",X"7",X"7",X"4",X"1",X"4",X"0",X"0",X"0",
		X"1",X"1",X"3",X"0",X"2",X"1",X"7",X"6",X"1",X"C",X"0",X"C",X"0",X"F",X"0",X"7",
		X"1",X"E",X"1",X"E",X"1",X"E",X"3",X"C",X"6",X"7",X"4",X"1",X"7",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"4",X"0",X"2",X"0",X"4",X"0",X"9",X"0",X"C",
		X"1",X"E",X"1",X"D",X"0",X"2",X"0",X"9",X"1",X"2",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"3",X"0",X"A",X"1",X"7",X"0",X"9",X"1",X"C",
		X"1",X"E",X"0",X"F",X"0",X"A",X"0",X"B",X"1",X"2",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"4",X"0",X"8",
		X"0",X"0",X"0",X"8",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"8",X"0",X"8",X"0",X"8",X"0",X"8",X"0",X"F",X"0",X"9",X"0",X"9",X"7",X"F",
		X"0",X"9",X"0",X"9",X"0",X"F",X"0",X"8",X"0",X"8",X"0",X"8",X"0",X"8",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
