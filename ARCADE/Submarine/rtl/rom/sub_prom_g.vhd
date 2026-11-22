library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity sub_prom_g is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(3 downto 0)
);
end entity;

architecture prom of sub_prom_g is
	type rom is array(0 to  255) of std_logic_vector(3 downto 0);
	signal rom_data: rom := (
		X"9",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"2",X"4",X"4",X"4",X"5",X"6",X"6",X"7",
		X"7",X"7",X"8",X"8",X"8",X"9",X"9",X"9",X"A",X"B",X"B",X"C",X"D",X"E",X"F",X"1",
		X"1",X"4",X"2",X"2",X"4",X"4",X"C",X"3",X"3",X"3",X"0",X"1",X"4",X"4",X"1",X"5",
		X"5",X"0",X"6",X"6",X"6",X"7",X"8",X"8",X"0",X"6",X"7",X"7",X"F",X"0",X"3",X"4",
		X"6",X"8",X"9",X"0",X"4",X"9",X"9",X"9",X"0",X"1",X"3",X"8",X"A",X"A",X"A",X"2",
		X"6",X"B",X"0",X"B",X"C",X"C",X"C",X"C",X"F",X"4",X"7",X"D",X"D",X"0",X"7",X"E",
		X"E",X"E",X"E",X"0",X"0",X"4",X"5",X"7",X"9",X"A",X"C",X"E",X"F",X"F",X"F",X"F",
		X"A",X"B",X"E",X"B",X"D",X"4",X"8",X"F",X"6",X"9",X"7",X"5",X"7",X"9",X"5",X"0",
		X"D",X"9",X"4",X"F",X"F",X"9",X"0",X"F",X"D",X"B",X"0",X"4",X"6",X"0",X"2",X"7",
		X"6",X"6",X"C",X"0",X"2",X"F",X"0",X"A",X"0",X"7",X"4",X"6",X"4",X"3",X"9",X"B",
		X"0",X"0",X"5",X"7",X"8",X"7",X"0",X"5",X"F",X"8",X"0",X"7",X"5",X"C",X"7",X"F",
		X"0",X"7",X"6",X"5",X"4",X"3",X"2",X"1",X"F",X"0",X"0",X"0",X"0",X"0",X"0",X"F",
		X"0",X"0",X"0",X"7",X"8",X"0",X"0",X"0",X"0",X"7",X"6",X"5",X"8",X"8",X"A",X"0",
		X"0",X"5",X"E",X"8",X"9",X"0",X"0",X"0",X"0",X"5",X"E",X"7",X"9",X"0",X"4",X"4",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"F",X"3",X"0",X"0",X"4",X"4",X"C",X"9");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
