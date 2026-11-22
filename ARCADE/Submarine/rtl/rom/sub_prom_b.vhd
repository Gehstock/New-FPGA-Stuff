library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity sub_prom_b is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(3 downto 0)
);
end entity;

architecture prom of sub_prom_b is
	type rom is array(0 to  255) of std_logic_vector(3 downto 0);
	signal rom_data: rom := (
		X"C",X"8",X"0",X"2",X"F",X"1",X"9",X"7",X"2",X"0",X"4",X"B",X"5",X"0",X"9",X"E",
		X"0",X"7",X"0",X"F",X"6",X"9",X"C",X"0",X"0",X"8",X"0",X"0",X"0",X"C",X"0",X"2",
		X"1",X"B",X"2",X"0",X"8",X"5",X"5",X"3",X"F",X"7",X"0",X"0",X"4",X"0",X"1",X"5",
		X"D",X"0",X"6",X"4",X"F",X"0",X"8",X"4",X"0",X"5",X"7",X"0",X"0",X"0",X"3",X"3",
		X"4",X"8",X"6",X"0",X"4",X"9",X"0",X"A",X"0",X"0",X"2",X"6",X"A",X"0",X"5",X"2",
		X"6",X"B",X"0",X"7",X"C",X"7",X"0",X"6",X"F",X"2",X"7",X"D",X"0",X"0",X"0",X"E",
		X"0",X"6",X"8",X"0",X"F",X"F",X"0",X"0",X"9",X"F",X"0",X"0",X"E",X"F",X"6",X"0",
		X"F",X"E",X"3",X"9",X"8",X"7",X"7",X"A",X"0",X"5",X"3",X"1",X"4",X"8",X"2",X"1",
		X"0",X"0",X"0",X"7",X"F",X"2",X"3",X"2",X"C",X"6",X"0",X"4",X"6",X"6",X"2",X"3",
		X"2",X"4",X"2",X"0",X"2",X"9",X"F",X"0",X"0",X"0",X"3",X"9",X"C",X"C",X"E",X"8",
		X"0",X"0",X"0",X"0",X"0",X"7",X"0",X"5",X"0",X"0",X"0",X"0",X"0",X"0",X"3",X"0",
		X"F",X"7",X"6",X"5",X"4",X"3",X"2",X"1",X"F",X"0",X"0",X"0",X"0",X"0",X"0",X"F",
		X"F",X"0",X"F",X"7",X"0",X"0",X"0",X"F",X"F",X"7",X"6",X"5",X"8",X"8",X"A",X"0",
		X"0",X"5",X"C",X"8",X"9",X"0",X"0",X"0",X"0",X"5",X"C",X"7",X"9",X"0",X"4",X"4",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"F",X"D",X"B",X"9",X"7",X"5",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"F",X"2",X"0",X"0",X"3",X"2",X"7",X"9");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
