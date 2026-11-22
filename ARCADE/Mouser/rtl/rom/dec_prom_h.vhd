library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity dec_prom_h is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(3 downto 0)
);
end entity;

architecture prom of dec_prom_h is
	type rom is array(0 to  255) of std_logic_vector(3 downto 0);
	signal rom_data: rom := (
		X"0",X"5",X"6",X"B",X"C",X"4",X"F",X"B",X"C",X"C",X"A",X"B",X"1",X"B",X"2",X"2",
		X"C",X"7",X"E",X"1",X"E",X"E",X"2",X"3",X"2",X"8",X"E",X"3",X"5",X"9",X"8",X"8",
		X"A",X"8",X"9",X"3",X"8",X"F",X"6",X"E",X"3",X"F",X"A",X"B",X"6",X"8",X"B",X"F",
		X"C",X"B",X"D",X"C",X"7",X"2",X"C",X"F",X"7",X"B",X"7",X"5",X"1",X"E",X"9",X"1",
		X"4",X"1",X"3",X"9",X"2",X"D",X"1",X"6",X"9",X"3",X"5",X"3",X"3",X"6",X"3",X"C",
		X"C",X"0",X"2",X"A",X"7",X"D",X"8",X"9",X"4",X"F",X"8",X"7",X"4",X"0",X"8",X"A",
		X"7",X"9",X"5",X"F",X"9",X"3",X"9",X"5",X"8",X"4",X"D",X"4",X"9",X"E",X"2",X"6",
		X"F",X"4",X"2",X"C",X"2",X"C",X"A",X"A",X"D",X"0",X"3",X"4",X"1",X"1",X"B",X"4",
		X"C",X"7",X"A",X"7",X"D",X"B",X"9",X"7",X"E",X"3",X"1",X"2",X"8",X"5",X"D",X"5",
		X"8",X"D",X"A",X"A",X"A",X"5",X"A",X"B",X"D",X"3",X"C",X"4",X"D",X"9",X"4",X"B",
		X"6",X"9",X"A",X"2",X"E",X"D",X"D",X"8",X"A",X"B",X"2",X"E",X"9",X"0",X"F",X"1",
		X"5",X"4",X"D",X"C",X"5",X"9",X"F",X"5",X"E",X"F",X"0",X"5",X"B",X"8",X"3",X"3",
		X"7",X"4",X"6",X"A",X"F",X"0",X"D",X"0",X"1",X"6",X"B",X"6",X"6",X"7",X"6",X"0",
		X"2",X"F",X"E",X"5",X"7",X"7",X"C",X"0",X"0",X"E",X"E",X"0",X"5",X"B",X"0",X"E",
		X"1",X"2",X"D",X"4",X"6",X"0",X"A",X"C",X"6",X"F",X"1",X"8",X"9",X"4",X"6",X"D",
		X"0",X"7",X"3",X"2",X"5",X"1",X"6",X"F",X"8",X"4",X"0",X"E",X"7",X"1",X"1",X"F");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
