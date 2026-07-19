library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity mc_editor_rom is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(9 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of mc_editor_rom is
	type rom is array(0 to  1023) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"CD",X"56",X"00",X"21",X"39",X"F0",X"06",X"07",X"7E",X"EF",X"23",X"10",X"FB",X"CD",X"C4",X"00",
		X"FE",X"51",X"C8",X"21",X"03",X"F0",X"E5",X"FE",X"5A",X"D0",X"FE",X"40",X"D8",X"6F",X"CD",X"33",
		X"F1",X"D8",X"7D",X"EB",X"FE",X"53",X"28",X"18",X"FE",X"4D",X"CA",X"C7",X"F0",X"FE",X"47",X"28",
		X"07",X"FE",X"54",X"C0",X"01",X"8E",X"F3",X"C5",X"E9",X"1E",X"1E",X"45",X"44",X"49",X"54",X"3E",
		X"E5",X"EB",X"CD",X"56",X"00",X"7B",X"E6",X"0F",X"FE",X"08",X"38",X"02",X"D6",X"08",X"67",X"7B",
		X"E6",X"F8",X"5F",X"24",X"2E",X"01",X"22",X"10",X"3C",X"01",X"82",X"3C",X"03",X"03",X"03",X"25",
		X"20",X"FA",X"C5",X"0E",X"08",X"CD",X"B3",X"F2",X"C5",X"0E",X"1D",X"2A",X"08",X"3C",X"09",X"22",
		X"08",X"3C",X"C1",X"0D",X"20",X"EF",X"C1",X"D1",X"3E",X"3E",X"02",X"21",X"C0",X"3E",X"22",X"08",
		X"3C",X"EF",X"CD",X"B2",X"F1",X"EB",X"CD",X"2D",X"F1",X"F5",X"C5",X"37",X"3F",X"0E",X"02",X"CC",
		X"E6",X"F0",X"CD",X"1D",X"F1",X"C1",X"30",X"03",X"F1",X"18",X"EB",X"F1",X"20",X"0C",X"73",X"03",
		X"ED",X"43",X"08",X"3C",X"CD",X"AD",X"F1",X"0B",X"3E",X"50",X"CD",X"C9",X"F1",X"EB",X"18",X"C8",
		X"3E",X"2D",X"EF",X"CD",X"33",X"F1",X"D8",X"EB",X"ED",X"52",X"30",X"06",X"EB",X"CD",X"1D",X"F1",
		X"18",X"F1",X"23",X"E5",X"C1",X"EB",X"C9",X"CD",X"B0",X"F0",X"3E",X"2D",X"EF",X"3E",X"3E",X"EF",
		X"CD",X"33",X"F1",X"D8",X"E5",X"ED",X"52",X"E1",X"38",X"03",X"ED",X"B0",X"C9",X"09",X"2B",X"EB",
		X"09",X"2B",X"EB",X"ED",X"B8",X"C9",X"E5",X"97",X"21",X"14",X"3C",X"77",X"23",X"77",X"ED",X"5B",
		X"24",X"3C",X"1A",X"FE",X"47",X"30",X"21",X"FE",X"30",X"38",X"1D",X"FE",X"3A",X"38",X"06",X"FE",
		X"41",X"38",X"15",X"D6",X"07",X"E6",X"0F",X"13",X"06",X"02",X"CD",X"FF",X"0B",X"23",X"23",X"0D",
		X"20",X"E0",X"5E",X"2B",X"56",X"97",X"E1",X"C9",X"00",X"00",X"00",X"37",X"E1",X"E5",X"2A",X"24",
		X"3C",X"22",X"08",X"3C",X"06",X"08",X"36",X"20",X"23",X"10",X"FB",X"E1",X"C9",X"C5",X"E5",X"0E",
		X"02",X"18",X"04",X"C5",X"E5",X"0E",X"04",X"51",X"06",X"00",X"2A",X"08",X"3C",X"22",X"24",X"3C",
		X"22",X"08",X"3C",X"36",X"5F",X"CD",X"C4",X"00",X"04",X"2A",X"08",X"3C",X"FE",X"5C",X"20",X"0A",
		X"2B",X"05",X"28",X"2D",X"36",X"20",X"05",X"2B",X"18",X"E6",X"FE",X"47",X"30",X"14",X"79",X"90",
		X"30",X"DE",X"2B",X"15",X"20",X"FC",X"54",X"5D",X"1B",X"C5",X"06",X"00",X"ED",X"B0",X"C1",X"51",
		X"18",X"E4",X"CB",X"51",X"28",X"0B",X"FE",X"7F",X"20",X"DA",X"CD",X"E6",X"F0",X"38",X"B6",X"18",
		X"02",X"FE",X"7F",X"E1",X"C1",X"C9",X"D5",X"C5",X"21",X"14",X"3C",X"73",X"2B",X"72",X"79",X"FE",
		X"04",X"28",X"01",X"23",X"16",X"02",X"97",X"ED",X"6F",X"F6",X"30",X"FE",X"3A",X"38",X"02",X"C6",
		X"07",X"EF",X"15",X"20",X"F1",X"23",X"0D",X"0D",X"20",X"EA",X"C1",X"D1",X"C9",X"C5",X"0E",X"02",
		X"18",X"03",X"C5",X"0E",X"04",X"E5",X"CD",X"86",X"F1",X"2A",X"08",X"3C",X"23",X"79",X"FE",X"02",
		X"28",X"01",X"23",X"22",X"08",X"3C",X"E1",X"C1",X"C9",X"D5",X"F5",X"3E",X"20",X"02",X"F1",X"ED",
		X"5B",X"10",X"3C",X"CD",X"DC",X"F1",X"ED",X"53",X"10",X"3C",X"D1",X"C9",X"FE",X"49",X"20",X"16",
		X"0B",X"0B",X"0B",X"2B",X"15",X"C0",X"16",X"08",X"1D",X"20",X"05",X"01",X"9A",X"3C",X"18",X"6E",
		X"D5",X"11",X"24",X"00",X"18",X"5D",X"FE",X"50",X"20",X"1C",X"03",X"03",X"03",X"23",X"14",X"7A",
		X"FE",X"09",X"C0",X"16",X"01",X"1C",X"7B",X"FE",X"09",X"20",X"05",X"01",X"29",X"3E",X"18",X"7A",
		X"D5",X"11",X"24",X"00",X"18",X"37",X"FE",X"4F",X"20",X"11",X"C5",X"01",X"08",X"00",X"97",X"ED",
		X"42",X"C1",X"1D",X"28",X"39",X"D5",X"11",X"3C",X"00",X"18",X"28",X"FE",X"4C",X"20",X"12",X"C5",
		X"01",X"08",X"00",X"09",X"C1",X"1C",X"7B",X"FE",X"09",X"28",X"4F",X"D5",X"11",X"3C",X"00",X"18",
		X"0C",X"FE",X"51",X"20",X"04",X"E1",X"E1",X"E1",X"C9",X"00",X"00",X"00",X"C9",X"E5",X"C5",X"E1",
		X"19",X"18",X"06",X"E5",X"C5",X"E1",X"97",X"ED",X"52",X"E5",X"C1",X"E1",X"D1",X"C9",X"D5",X"C5",
		X"E5",X"21",X"05",X"3E",X"11",X"41",X"3E",X"01",X"86",X"01",X"ED",X"B8",X"21",X"80",X"3C",X"22",
		X"08",X"3C",X"22",X"24",X"3C",X"0E",X"04",X"CD",X"E6",X"F0",X"21",X"08",X"00",X"EB",X"97",X"ED",
		X"52",X"EB",X"CD",X"B3",X"F2",X"E1",X"C1",X"D1",X"1C",X"C9",X"D5",X"C5",X"E5",X"21",X"BC",X"3C",
		X"11",X"80",X"3C",X"01",X"86",X"01",X"ED",X"B0",X"21",X"24",X"3E",X"22",X"08",X"3C",X"22",X"24",
		X"3C",X"0E",X"04",X"CD",X"E6",X"F0",X"21",X"08",X"00",X"19",X"EB",X"CD",X"B3",X"F2",X"E1",X"C1",
		X"D1",X"1D",X"C9",X"CD",X"B2",X"F1",X"06",X"08",X"1A",X"13",X"D5",X"5F",X"CD",X"AD",X"F1",X"D1",
		X"10",X"F6",X"C9",X"CD",X"56",X"00",X"FB",X"21",X"87",X"F3",X"06",X"07",X"7E",X"EF",X"23",X"10",
		X"FB",X"21",X"C6",X"F2",X"E5",X"CD",X"C4",X"00",X"FE",X"54",X"20",X"06",X"97",X"11",X"00",X"00",
		X"18",X"40",X"FE",X"52",X"20",X"10",X"CD",X"5E",X"F3",X"C8",X"CD",X"7C",X"F3",X"21",X"00",X"E0",
		X"01",X"00",X"04",X"ED",X"B0",X"C9",X"FE",X"50",X"20",X"5F",X"CD",X"5E",X"F3",X"C8",X"3E",X"79",
		X"D3",X"F9",X"EB",X"3E",X"32",X"11",X"00",X"E0",X"01",X"00",X"04",X"E5",X"F5",X"3E",X"FF",X"3D",
		X"20",X"FD",X"F1",X"ED",X"A0",X"EA",X"0C",X"F3",X"E1",X"3D",X"20",X"E9",X"3E",X"F9",X"D3",X"F9",
		X"37",X"EB",X"CD",X"7C",X"F3",X"21",X"00",X"E0",X"01",X"00",X"04",X"FD",X"21",X"00",X"00",X"1A",
		X"38",X"02",X"3E",X"FF",X"ED",X"A1",X"F5",X"28",X"08",X"FD",X"23",X"3E",X"1E",X"EF",X"CD",X"B2",
		X"F1",X"13",X"F1",X"EA",X"2F",X"F3",X"FD",X"E5",X"D1",X"7A",X"B3",X"C8",X"CD",X"B2",X"F1",X"3E",
		X"45",X"EF",X"3E",X"52",X"EF",X"3E",X"52",X"EF",X"C9",X"FE",X"51",X"C0",X"E1",X"C9",X"CD",X"33",
		X"F1",X"30",X"02",X"97",X"C9",X"3E",X"2D",X"EF",X"D5",X"EB",X"01",X"FF",X"03",X"09",X"EB",X"CD",
		X"B2",X"F1",X"3E",X"3F",X"EF",X"CD",X"C4",X"00",X"FE",X"4E",X"D1",X"C9",X"F3",X"06",X"40",X"0E",
		X"FF",X"0D",X"20",X"FD",X"10",X"F9",X"C9",X"1E",X"1E",X"50",X"52",X"4F",X"4D",X"3E",X"E5",X"D5",
		X"C5",X"F5",X"3E",X"1E",X"EF",X"06",X"04",X"D1",X"CD",X"B2",X"F1",X"10",X"FA",X"C9",X"FB",X"F5",
		X"3A",X"BF",X"13",X"CB",X"47",X"28",X"F9",X"F1",X"ED",X"4D",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"
	);
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
