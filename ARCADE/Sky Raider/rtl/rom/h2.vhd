library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity h2 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(8 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of h2 is
	type rom is array(0 to  511) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"38",X"6C",X"C6",X"C6",X"FE",X"C6",X"C6",
		X"00",X"FC",X"C6",X"C6",X"FC",X"C6",X"C6",X"FC",X"00",X"3C",X"66",X"C0",X"C0",X"C0",X"66",X"3C",
		X"00",X"F8",X"CC",X"C6",X"C6",X"C6",X"CC",X"F8",X"00",X"FC",X"C0",X"C0",X"F8",X"C0",X"C0",X"FE",
		X"00",X"FE",X"C0",X"C0",X"FC",X"C0",X"C0",X"C0",X"00",X"3E",X"60",X"C0",X"CE",X"C6",X"66",X"3E",
		X"00",X"C6",X"C6",X"C6",X"FE",X"C6",X"C6",X"C6",X"00",X"FC",X"30",X"30",X"30",X"30",X"30",X"FC",
		X"00",X"06",X"06",X"06",X"06",X"06",X"C6",X"7C",X"00",X"C6",X"CC",X"D8",X"F0",X"F8",X"DC",X"CE",
		X"00",X"C0",X"C0",X"C0",X"C0",X"C0",X"C0",X"FC",X"00",X"C6",X"EE",X"FE",X"FE",X"D6",X"C6",X"C6",
		X"00",X"C6",X"E6",X"F6",X"FE",X"DE",X"CE",X"C6",X"00",X"7C",X"C6",X"C6",X"C6",X"C6",X"C6",X"7C",
		X"00",X"FC",X"C6",X"C6",X"C6",X"FC",X"C0",X"C0",X"00",X"7C",X"C6",X"C6",X"C6",X"DE",X"CC",X"7A",
		X"00",X"FC",X"C6",X"C6",X"CE",X"F8",X"DC",X"CE",X"00",X"78",X"CC",X"C0",X"7C",X"06",X"C6",X"7C",
		X"00",X"FC",X"30",X"30",X"30",X"30",X"30",X"30",X"00",X"C6",X"C6",X"C6",X"C6",X"C6",X"C6",X"7C",
		X"00",X"C6",X"C6",X"C6",X"EE",X"7C",X"38",X"10",X"00",X"C6",X"C6",X"D6",X"FE",X"FE",X"EE",X"C6",
		X"00",X"C6",X"EE",X"7C",X"38",X"7C",X"EE",X"C6",X"00",X"CC",X"CC",X"CC",X"78",X"30",X"30",X"30",
		X"00",X"FE",X"0E",X"1C",X"38",X"70",X"E0",X"FE",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"90",X"90",X"F7",X"92",X"92",X"02",X"12",X"0C",X"F0",X"80",X"E9",X"89",X"8F",X"09",X"09",X"00",
		X"88",X"D8",X"A8",X"89",X"8D",X"0D",X"0B",X"0B",X"80",X"80",X"80",X"91",X"FB",X"15",X"11",X"11",
		X"00",X"38",X"4C",X"C6",X"C6",X"C6",X"64",X"38",X"00",X"30",X"70",X"30",X"30",X"30",X"30",X"FC",
		X"00",X"7C",X"C6",X"0E",X"3C",X"78",X"E0",X"FE",X"00",X"7E",X"0C",X"18",X"3C",X"06",X"C6",X"7C",
		X"00",X"1C",X"3C",X"6C",X"CC",X"FE",X"0C",X"0C",X"00",X"FC",X"C0",X"FC",X"06",X"06",X"C6",X"7C",
		X"00",X"3C",X"60",X"C0",X"FC",X"C6",X"C6",X"7C",X"00",X"FE",X"C6",X"0C",X"18",X"30",X"30",X"30",
		X"00",X"78",X"C4",X"E4",X"78",X"9E",X"86",X"7C",X"00",X"7C",X"C6",X"C6",X"7E",X"06",X"0C",X"78",
		X"00",X"38",X"6C",X"C6",X"C6",X"FE",X"C6",X"C6",X"00",X"FC",X"C6",X"C6",X"FC",X"C6",X"C6",X"FC",
		X"00",X"3C",X"66",X"C0",X"C0",X"C0",X"66",X"3C",X"00",X"F8",X"CC",X"C6",X"C6",X"C6",X"CC",X"F8",
		X"00",X"FC",X"C0",X"C0",X"F8",X"C0",X"C0",X"FE",X"00",X"FE",X"C0",X"C0",X"FC",X"C0",X"C0",X"C0");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
