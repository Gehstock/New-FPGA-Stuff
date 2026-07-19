library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity n5 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(3 downto 0)
);
end entity;

architecture prom of n5 is
	type rom is array(0 to  255) of std_logic_vector(3 downto 0);
	signal rom_data: rom := (
		X"0",X"0",X"1",X"6",X"1",X"C",X"3",X"C",X"8",X"8",X"F",X"0",X"7",X"2",X"F",X"6",
		X"F",X"4",X"F",X"8",X"F",X"C",X"B",X"0",X"9",X"0",X"0",X"F",X"0",X"E",X"0",X"0",
		X"0",X"A",X"3",X"4",X"0",X"C",X"1",X"0",X"8",X"0",X"F",X"0",X"7",X"1",X"F",X"3",
		X"D",X"6",X"F",X"4",X"F",X"0",X"B",X"2",X"1",X"0",X"0",X"C",X"4",X"C",X"0",X"0",
		X"0",X"0",X"0",X"0",X"2",X"0",X"4",X"0",X"C",X"0",X"5",X"0",X"3",X"0",X"7",X"0",
		X"B",X"8",X"3",X"0",X"5",X"0",X"D",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"8",X"0",X"6",X"0",X"C",X"0",X"5",X"0",X"3",X"0",X"7",X"0",
		X"B",X"8",X"3",X"0",X"4",X"8",X"D",X"0",X"8",X"0",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"2",X"0",X"1",X"0",X"3",X"0",
		X"5",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",
		X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"7",X"0",X"4",X"0",X"4",X"0",X"F",X"F",
		X"4",X"0",X"4",X"0",X"7",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",X"0",
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
