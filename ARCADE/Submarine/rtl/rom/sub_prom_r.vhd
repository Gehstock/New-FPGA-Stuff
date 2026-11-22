library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity sub_prom_r is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(3 downto 0)
);
end entity;

architecture prom of sub_prom_r is
	type rom is array(0 to  255) of std_logic_vector(3 downto 0);
	signal rom_data: rom := (
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"1",
		X"1",X"1",X"2",X"2",X"2",X"2",X"2",X"3",X"3",X"3",X"4",X"4",X"4",X"4",X"5",X"5",
		X"5",X"6",X"6",X"6",X"6",X"6",X"6",X"6",X"7",X"7",X"7",X"7",X"7",X"8",X"8",X"8",
		X"8",X"8",X"8",X"9",X"9",X"9",X"9",X"9",X"A",X"A",X"A",X"A",X"A",X"A",X"A",X"B",
		X"B",X"B",X"C",X"C",X"C",X"C",X"C",X"C",X"C",X"D",X"D",X"D",X"D",X"E",X"E",X"E",
		X"E",X"E",X"E",X"F",X"F",X"F",X"F",X"F",X"F",X"F",X"F",X"F",X"F",X"F",X"F",X"F",
		X"E",X"0",X"0",X"B",X"D",X"3",X"A",X"F",X"6",X"A",X"8",X"6",X"8",X"A",X"6",X"9",
		X"F",X"F",X"F",X"F",X"0",X"0",X"0",X"0",X"0",X"B",X"D",X"C",X"E",X"E",X"A",X"5",
		X"4",X"4",X"1",X"B",X"C",X"F",X"C",X"D",X"0",X"C",X"C",X"4",X"5",X"9",X"B",X"7",
		X"0",X"D",X"F",X"F",X"F",X"F",X"E",X"B",X"0",X"F",X"E",X"E",X"F",X"9",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"4",X"6",X"8",X"C",X"D",X"6",X"0",
		X"F",X"C",X"F",X"0",X"F",X"8",X"6",X"F",X"F",X"7",X"6",X"0",X"8",X"6",X"A",X"0",
		X"0",X"0",X"0",X"8",X"9",X"C",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"C",X"0",X"0",
		X"F",X"F",X"F",X"F",X"F",X"F",X"F",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"F",X"A",X"0",X"0",X"8",X"D",X"C",X"9");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
