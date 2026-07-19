library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity a6 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(3 downto 0)
);
end entity;

architecture prom of a6 is
	type rom is array(0 to  255) of std_logic_vector(3 downto 0);
	signal rom_data: rom := (
		X"0",X"F",X"2",X"D",X"4",X"B",X"6",X"9",X"8",X"7",X"A",X"5",X"C",X"3",X"E",X"1",
		X"0",X"F",X"3",X"C",X"5",X"A",X"7",X"8",X"9",X"6",X"B",X"4",X"D",X"2",X"E",X"1",
		X"0",X"F",X"2",X"D",X"4",X"B",X"6",X"9",X"8",X"7",X"A",X"5",X"C",X"3",X"E",X"1",
		X"F",X"0",X"1",X"E",X"3",X"C",X"5",X"A",X"6",X"9",X"8",X"7",X"A",X"5",X"C",X"3",
		X"D",X"2",X"F",X"0",X"1",X"E",X"2",X"D",X"4",X"B",X"6",X"9",X"7",X"8",X"9",X"6",
		X"B",X"4",X"C",X"3",X"E",X"1",X"F",X"0",X"1",X"E",X"2",X"D",X"4",X"B",X"6",X"9",
		X"7",X"8",X"9",X"6",X"A",X"5",X"B",X"4",X"D",X"2",X"E",X"1",X"0",X"F",X"1",X"E",
		X"3",X"C",X"4",X"B",X"5",X"A",X"7",X"8",X"8",X"7",X"A",X"5",X"B",X"4",X"C",X"3",
		X"E",X"1",X"F",X"0",X"0",X"F",X"2",X"D",X"3",X"C",X"4",X"B",X"5",X"A",X"7",X"8",
		X"8",X"7",X"9",X"6",X"A",X"5",X"C",X"3",X"D",X"2",X"E",X"1",X"F",X"0",X"0",X"F",
		X"2",X"D",X"3",X"C",X"4",X"B",X"5",X"A",X"6",X"9",X"7",X"8",X"8",X"7",X"9",X"6",
		X"B",X"4",X"C",X"3",X"D",X"2",X"E",X"1",X"F",X"0",X"0",X"F",X"1",X"E",X"2",X"D",
		X"3",X"C",X"4",X"B",X"5",X"A",X"6",X"9",X"7",X"8",X"8",X"7",X"9",X"6",X"A",X"5",
		X"B",X"4",X"C",X"3",X"D",X"2",X"E",X"1",X"F",X"0",X"0",X"F",X"1",X"E",X"2",X"D",
		X"3",X"C",X"3",X"C",X"4",X"B",X"5",X"A",X"6",X"9",X"7",X"8",X"8",X"7",X"9",X"6",
		X"4",X"B",X"F",X"0",X"A",X"5",X"5",X"A",X"0",X"F",X"B",X"4",X"6",X"9",X"1",X"E");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
