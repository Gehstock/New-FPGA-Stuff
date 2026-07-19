library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity SE24_000 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(9 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of SE24_000 is
	type rom is array(0 to  1023) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"01",X"F8",X"03",X"21",X"1F",X"00",X"ED",X"B3",X"01",X"F9",X"02",X"ED",X"B3",X"01",X"FA",X"02",
		X"ED",X"B3",X"01",X"FB",X"02",X"ED",X"B3",X"31",X"50",X"3C",X"ED",X"5E",X"C3",X"5A",X"01",X"05",
		X"0A",X"28",X"FF",X"10",X"7F",X"14",X"7F",X"32",X"46",X"00",X"46",X"00",X"E5",X"C5",X"0E",X"0C",
		X"21",X"50",X"3C",X"22",X"08",X"3C",X"06",X"1B",X"36",X"2E",X"23",X"10",X"FB",X"36",X"E0",X"23",
		X"0D",X"20",X"F3",X"C1",X"E1",X"C9",X"08",X"DB",X"FA",X"2F",X"C6",X"10",X"87",X"FE",X"18",X"30",
		X"1B",X"D9",X"21",X"70",X"00",X"85",X"6F",X"46",X"2C",X"66",X"68",X"11",X"69",X"00",X"06",X"08",
		X"3A",X"00",X"14",X"00",X"ED",X"57",X"00",X"D5",X"E9",X"10",X"F9",X"D9",X"08",X"FB",X"ED",X"4D",
		X"50",X"38",X"6C",X"38",X"88",X"38",X"A4",X"38",X"C0",X"38",X"DC",X"38",X"F8",X"38",X"14",X"39",
		X"30",X"39",X"4C",X"39",X"68",X"39",X"84",X"39",X"E5",X"2A",X"08",X"3C",X"FE",X"1E",X"28",X"2C",
		X"77",X"23",X"3E",X"A0",X"BD",X"20",X"1B",X"3E",X"3D",X"BC",X"20",X"16",X"D5",X"C5",X"11",X"50",
		X"3C",X"21",X"6C",X"3C",X"01",X"33",X"01",X"ED",X"B0",X"06",X"1B",X"2B",X"36",X"2E",X"10",X"FB",
		X"C1",X"D1",X"CB",X"7E",X"28",X"01",X"2B",X"22",X"08",X"3C",X"E1",X"C9",X"CB",X"7E",X"23",X"28",
		X"FB",X"18",X"CF",X"3A",X"00",X"12",X"E6",X"0F",X"20",X"F9",X"3A",X"00",X"10",X"E6",X"0E",X"20",
		X"F2",X"C9",X"E5",X"C5",X"CD",X"C3",X"00",X"3D",X"20",X"FD",X"CD",X"C3",X"00",X"21",X"FE",X"13",
		X"0E",X"00",X"7E",X"BE",X"20",X"FC",X"06",X"00",X"CB",X"5F",X"20",X"16",X"04",X"87",X"20",X"F8",
		X"0C",X"37",X"CB",X"15",X"CB",X"14",X"7C",X"FE",X"23",X"28",X"E2",X"E6",X"03",X"C6",X"10",X"67",
		X"18",X"E0",X"3A",X"FF",X"11",X"CB",X"47",X"28",X"02",X"CB",X"D0",X"78",X"C6",X"29",X"6F",X"26",
		X"01",X"7E",X"81",X"FE",X"0A",X"38",X"C6",X"FE",X"5E",X"28",X"C2",X"FE",X"5B",X"20",X"02",X"3E",
		X"20",X"F5",X"CD",X"88",X"00",X"F1",X"C1",X"E1",X"C9",X"30",X"41",X"4B",X"55",X"20",X"26",X"3A",
		X"00",X"2A",X"08",X"3C",X"E5",X"36",X"5F",X"CD",X"D2",X"00",X"2A",X"08",X"3C",X"FE",X"5C",X"20",
		X"07",X"2B",X"36",X"20",X"2B",X"22",X"08",X"3C",X"FE",X"5D",X"20",X"E9",X"D1",X"C9",X"42",X"41",
		X"53",X"49",X"43",X"2D",X"53",X"45",X"20",X"32",X"2E",X"34",X"CD",X"2C",X"00",X"FB",X"21",X"4E",
		X"01",X"06",X"0C",X"7E",X"CD",X"88",X"00",X"23",X"10",X"F9",X"3A",X"A0",X"3D",X"FE",X"1E",X"28",
		X"22",X"21",X"04",X"00",X"22",X"06",X"3C",X"2E",X"00",X"22",X"0A",X"3C",X"22",X"0C",X"3C",X"21",
		X"0F",X"27",X"22",X"A1",X"3D",X"26",X"1E",X"2E",X"DE",X"22",X"A3",X"3D",X"7C",X"32",X"A0",X"3D",
		X"CD",X"1D",X"03",X"31",X"50",X"3C",X"FB",X"21",X"D0",X"07",X"E5",X"2A",X"08",X"3C",X"2B",X"CB",
		X"7E",X"3E",X"1E",X"CC",X"88",X"00",X"3E",X"3E",X"CD",X"88",X"00",X"CD",X"31",X"01",X"1A",X"FE",
		X"40",X"38",X"19",X"CD",X"DC",X"01",X"3E",X"20",X"12",X"FD",X"36",X"00",X"3B",X"FD",X"36",X"01",
		X"DE",X"3E",X"1E",X"CD",X"88",X"00",X"11",X"10",X"3C",X"C3",X"40",X"03",X"FE",X"30",X"38",X"C3",
		X"ED",X"53",X"08",X"3C",X"CD",X"DC",X"01",X"CD",X"3D",X"02",X"18",X"B7",X"CD",X"CF",X"05",X"FD",
		X"22",X"0E",X"3C",X"FD",X"21",X"10",X"3C",X"01",X"03",X"00",X"26",X"40",X"1A",X"FE",X"5D",X"C8",
		X"FE",X"27",X"20",X"05",X"7C",X"C6",X"40",X"67",X"1A",X"BC",X"FA",X"2F",X"02",X"C5",X"21",X"6B",
		X"07",X"01",X"90",X"00",X"1A",X"ED",X"B1",X"C2",X"2B",X"02",X"D5",X"DD",X"E1",X"2B",X"2B",X"CB",
		X"7E",X"23",X"23",X"28",X"EF",X"CB",X"7E",X"20",X"0B",X"DD",X"23",X"DD",X"7E",X"00",X"ED",X"A1",
		X"20",X"E2",X"18",X"F1",X"DD",X"E5",X"D1",X"7E",X"A7",X"18",X"01",X"1A",X"C1",X"26",X"40",X"FD",
		X"77",X"00",X"13",X"84",X"FE",X"60",X"28",X"B4",X"0C",X"FD",X"23",X"18",X"AF",X"FD",X"36",X"00",
		X"1E",X"ED",X"43",X"02",X"3C",X"ED",X"4B",X"06",X"3C",X"21",X"A1",X"3D",X"18",X"09",X"3E",X"1E",
		X"23",X"23",X"ED",X"B1",X"E2",X"75",X"02",X"E5",X"5E",X"23",X"56",X"2A",X"0E",X"3C",X"97",X"ED",
		X"52",X"E1",X"28",X"30",X"30",X"E8",X"2B",X"09",X"54",X"5D",X"C5",X"ED",X"4B",X"02",X"3C",X"09",
		X"EB",X"C1",X"ED",X"B8",X"23",X"54",X"5D",X"21",X"0E",X"3C",X"ED",X"4B",X"02",X"3C",X"ED",X"B0",
		X"2A",X"06",X"3C",X"ED",X"4B",X"02",X"3C",X"09",X"22",X"06",X"3C",X"11",X"0E",X"3C",X"0E",X"00",
		X"CD",X"AC",X"02",X"C9",X"E5",X"ED",X"5B",X"06",X"3C",X"1B",X"23",X"0B",X"7E",X"FE",X"1E",X"0B",
		X"1B",X"23",X"20",X"F8",X"ED",X"53",X"06",X"3C",X"D1",X"ED",X"B0",X"C9",X"1A",X"6F",X"13",X"1A",
		X"67",X"13",X"CD",X"1F",X"04",X"1A",X"A7",X"FA",X"C4",X"02",X"CD",X"88",X"00",X"1A",X"FE",X"1E",
		X"13",X"20",X"F2",X"C9",X"21",X"6B",X"07",X"01",X"90",X"00",X"ED",X"B1",X"06",X"FF",X"2B",X"2B",
		X"04",X"CB",X"7E",X"28",X"FA",X"23",X"7E",X"F6",X"20",X"CD",X"88",X"00",X"10",X"F7",X"3E",X"20",
		X"18",X"D8",X"11",X"A1",X"3D",X"01",X"00",X"0B",X"13",X"1A",X"FE",X"27",X"1B",X"28",X"0C",X"C5",
		X"CD",X"AC",X"02",X"C1",X"10",X"F2",X"CD",X"D2",X"00",X"18",X"EA",X"CD",X"AC",X"02",X"11",X"A1",
		X"3D",X"2A",X"06",X"3C",X"19",X"54",X"5D",X"23",X"7E",X"FE",X"00",X"28",X"FA",X"2B",X"2B",X"2B",
		X"ED",X"52",X"CD",X"1F",X"04",X"3E",X"42",X"CD",X"88",X"00",X"C3",X"93",X"01",X"11",X"A1",X"3D",
		X"2A",X"06",X"3C",X"19",X"23",X"3E",X"FF",X"77",X"BE",X"20",X"05",X"97",X"77",X"BE",X"28",X"F4",
		X"2B",X"22",X"00",X"3C",X"C9",X"CD",X"2C",X"00",X"CD",X"1D",X"03",X"11",X"A1",X"3D",X"13",X"13",
		X"1A",X"FE",X"80",X"FA",X"D6",X"03",X"FE",X"DE",X"FA",X"4D",X"07",X"13",X"6F",X"26",X"07",X"7E",
		X"23",X"66",X"6F",X"E9",X"CD",X"36",X"05",X"21",X"A1",X"3D",X"ED",X"4B",X"06",X"3C",X"3A",X"04",
		X"3C",X"ED",X"A1",X"20",X"0B",X"3A",X"05",X"3C",X"ED",X"A1",X"20",X"04",X"EB",X"C3",X"40",X"03",
		X"3E",X"1E",X"ED",X"B1",X"28",X"E8",X"C3",X"4D",X"07",X"CD",X"36",X"05",X"1A",X"FE",X"D1",X"20",
		X"01",X"13",X"97",X"85",X"C2",X"40",X"03",X"1A",X"FE",X"3B",X"13",X"CA",X"40",X"03",X"FE",X"1E",
		X"CA",X"3E",X"03",X"18",X"F2",X"D5",X"18",X"BC",X"D1",X"18",X"EC",X"CD",X"82",X"04",X"CA",X"BB",
		X"03",X"CD",X"36",X"05",X"D5",X"CD",X"31",X"01",X"ED",X"53",X"08",X"3C",X"1A",X"FE",X"5D",X"28",
		X"03",X"CD",X"36",X"05",X"CD",X"1C",X"04",X"D1",X"CD",X"DB",X"04",X"CD",X"10",X"04",X"18",X"DB",
		X"CD",X"82",X"04",X"28",X"06",X"CD",X"36",X"05",X"CD",X"1C",X"04",X"CD",X"10",X"04",X"18",X"F0",
		X"CD",X"2C",X"00",X"C3",X"87",X"03",X"CD",X"E9",X"04",X"1A",X"FE",X"3D",X"C2",X"4D",X"07",X"13",
		X"DD",X"E5",X"CD",X"36",X"05",X"DD",X"E1",X"CD",X"DF",X"04",X"C3",X"87",X"03",X"CD",X"36",X"05",
		X"CD",X"10",X"04",X"E5",X"CD",X"36",X"05",X"4D",X"E1",X"71",X"23",X"CD",X"10",X"04",X"18",X"F3"
	);
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
