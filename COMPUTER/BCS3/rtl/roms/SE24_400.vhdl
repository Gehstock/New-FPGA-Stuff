library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity SE24_400 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(9 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of SE24_400 is
	type rom is array(0 to  1023) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"CD",X"36",X"05",X"4D",X"CD",X"10",X"04",X"C5",X"CD",X"36",X"05",X"C1",X"ED",X"69",X"18",X"F4",
		X"1A",X"FE",X"2C",X"28",X"05",X"33",X"33",X"C3",X"87",X"03",X"13",X"C9",X"2A",X"04",X"3C",X"D5",
		X"C5",X"0E",X"20",X"CB",X"7C",X"28",X"04",X"0E",X"2D",X"CB",X"BC",X"11",X"10",X"27",X"CD",X"5E",
		X"04",X"11",X"E8",X"03",X"CD",X"5E",X"04",X"11",X"64",X"00",X"CD",X"5E",X"04",X"11",X"0A",X"00",
		X"CD",X"5E",X"04",X"79",X"FE",X"00",X"C4",X"88",X"00",X"7D",X"C6",X"30",X"CD",X"88",X"00",X"2A",
		X"08",X"3C",X"CB",X"7E",X"20",X"05",X"36",X"20",X"23",X"18",X"F7",X"C1",X"D1",X"C9",X"3E",X"2F",
		X"37",X"3F",X"ED",X"52",X"3C",X"30",X"FB",X"19",X"FE",X"30",X"47",X"79",X"28",X"0C",X"FE",X"00",
		X"C4",X"88",X"00",X"0E",X"00",X"78",X"CD",X"88",X"00",X"C9",X"FE",X"00",X"3E",X"20",X"20",X"F6",
		X"18",X"F3",X"1A",X"FE",X"1E",X"CA",X"4D",X"07",X"FE",X"23",X"20",X"0D",X"13",X"CD",X"36",X"05",
		X"3E",X"20",X"CD",X"88",X"00",X"2D",X"20",X"F8",X"C9",X"FE",X"27",X"20",X"10",X"13",X"1A",X"FE",
		X"27",X"13",X"C8",X"FE",X"1E",X"CA",X"4D",X"07",X"CD",X"88",X"00",X"18",X"F1",X"FE",X"DD",X"20",
		X"11",X"13",X"CD",X"36",X"05",X"21",X"04",X"3C",X"CD",X"CD",X"04",X"CD",X"CD",X"04",X"3E",X"20",
		X"18",X"06",X"FE",X"2F",X"C0",X"13",X"3E",X"1E",X"CD",X"88",X"00",X"97",X"C9",X"3E",X"30",X"ED",
		X"6F",X"FE",X"3A",X"38",X"02",X"C6",X"07",X"CD",X"88",X"00",X"C9",X"DD",X"2A",X"02",X"3C",X"2A",
		X"04",X"3C",X"DD",X"74",X"FD",X"DD",X"75",X"FE",X"C9",X"C5",X"DD",X"2A",X"00",X"3C",X"1A",X"FE",
		X"40",X"FA",X"4D",X"07",X"47",X"0E",X"00",X"13",X"1A",X"A7",X"FA",X"04",X"05",X"FE",X"40",X"FA",
		X"04",X"05",X"4F",X"13",X"78",X"DD",X"BE",X"00",X"20",X"0C",X"79",X"DD",X"BE",X"FF",X"20",X"06",
		X"DD",X"22",X"02",X"3C",X"C1",X"C9",X"DD",X"7E",X"00",X"A7",X"28",X"0A",X"DD",X"2B",X"DD",X"2B",
		X"DD",X"2B",X"DD",X"2B",X"18",X"DE",X"DD",X"70",X"00",X"DD",X"71",X"FF",X"DD",X"7E",X"FD",X"A7",
		X"C2",X"4D",X"07",X"C3",X"10",X"05",X"0E",X"00",X"CD",X"4C",X"06",X"FD",X"E5",X"E1",X"78",X"A7",
		X"FA",X"77",X"05",X"F5",X"CD",X"4C",X"06",X"F1",X"B8",X"F2",X"52",X"05",X"E5",X"F5",X"0C",X"C3",
		X"3B",X"05",X"D5",X"16",X"00",X"5F",X"DD",X"21",X"74",X"06",X"DD",X"19",X"FD",X"E5",X"D1",X"DD",
		X"E9",X"D1",X"7C",X"C6",X"80",X"B5",X"20",X"02",X"CB",X"BC",X"79",X"FE",X"00",X"28",X"CF",X"0D",
		X"E5",X"FD",X"E1",X"F1",X"E1",X"18",X"D1",X"22",X"04",X"3C",X"C9",X"1A",X"FE",X"28",X"20",X"08",
		X"CD",X"BC",X"05",X"44",X"4D",X"C3",X"48",X"06",X"FE",X"D7",X"20",X"07",X"CD",X"BC",X"05",X"4E",
		X"C3",X"48",X"06",X"FE",X"D9",X"20",X"09",X"CD",X"BC",X"05",X"4D",X"ED",X"48",X"C3",X"48",X"06",
		X"FE",X"DA",X"20",X"26",X"CD",X"BC",X"05",X"7D",X"FE",X"00",X"28",X"0B",X"ED",X"5F",X"87",X"67",
		X"DB",X"F9",X"84",X"95",X"30",X"FD",X"85",X"3C",X"4F",X"C3",X"48",X"06",X"13",X"CD",X"36",X"05",
		X"1A",X"FE",X"29",X"C2",X"4D",X"07",X"13",X"06",X"00",X"C9",X"FE",X"40",X"F2",X"3F",X"06",X"1A",
		X"FD",X"21",X"00",X"00",X"21",X"0D",X"3C",X"0E",X"00",X"FE",X"2D",X"20",X"03",X"0E",X"80",X"13",
		X"1A",X"FE",X"30",X"38",X"15",X"FE",X"3A",X"38",X"0B",X"FE",X"41",X"38",X"0D",X"D6",X"07",X"FE",
		X"40",X"D2",X"FA",X"05",X"E6",X"0F",X"23",X"77",X"18",X"E5",X"FE",X"41",X"28",X"2F",X"7E",X"FE",
		X"0A",X"38",X"04",X"1B",X"2B",X"18",X"F7",X"D5",X"5E",X"51",X"FD",X"19",X"11",X"0A",X"00",X"CD",
		X"25",X"06",X"1E",X"64",X"CD",X"25",X"06",X"11",X"E8",X"03",X"CD",X"25",X"06",X"11",X"10",X"27",
		X"CD",X"25",X"06",X"D1",X"C9",X"2B",X"7E",X"3D",X"F8",X"FD",X"19",X"18",X"FA",X"13",X"7E",X"2B",
		X"ED",X"6F",X"4E",X"36",X"00",X"2B",X"7E",X"2B",X"ED",X"6F",X"46",X"36",X"00",X"18",X"09",X"CD",
		X"E9",X"04",X"DD",X"46",X"FD",X"DD",X"4E",X"FE",X"C5",X"FD",X"E1",X"C9",X"E5",X"C5",X"CD",X"7B",
		X"05",X"21",X"61",X"06",X"01",X"13",X"00",X"1A",X"ED",X"B1",X"20",X"01",X"13",X"C1",X"46",X"E1",
		X"C9",X"3D",X"00",X"3C",X"03",X"3E",X"06",X"D2",X"09",X"D6",X"0C",X"2B",X"0F",X"2D",X"12",X"2F",
		X"15",X"2A",X"18",X"00",X"C3",X"C7",X"06",X"C3",X"E4",X"06",X"C3",X"D4",X"06",X"C3",X"B5",X"06",
		X"C3",X"BE",X"06",X"C3",X"AB",X"06",X"C3",X"A2",X"06",X"C3",X"16",X"07",X"C3",X"F4",X"06",X"E5",
		X"EB",X"CD",X"95",X"06",X"EB",X"CB",X"7C",X"C8",X"7C",X"2F",X"67",X"7D",X"2F",X"6F",X"23",X"CB",
		X"FC",X"C9",X"7A",X"B3",X"CA",X"61",X"05",X"7A",X"EE",X"80",X"57",X"CD",X"90",X"06",X"19",X"CD",
		X"95",X"06",X"C3",X"61",X"05",X"7C",X"A2",X"67",X"7D",X"A3",X"6F",X"C3",X"61",X"05",X"7C",X"B2",
		X"67",X"7D",X"B3",X"6F",X"C3",X"61",X"05",X"A7",X"ED",X"52",X"21",X"00",X"00",X"C2",X"61",X"05",
		X"2C",X"C3",X"61",X"05",X"CD",X"90",X"06",X"37",X"ED",X"52",X"21",X"00",X"00",X"FA",X"61",X"05",
		X"2C",X"C3",X"61",X"05",X"CD",X"90",X"06",X"A7",X"ED",X"52",X"21",X"00",X"00",X"F2",X"61",X"05",
		X"2C",X"C3",X"61",X"05",X"C5",X"4D",X"7C",X"AA",X"E6",X"80",X"F5",X"7C",X"06",X"0F",X"21",X"00",
		X"00",X"CB",X"BF",X"CB",X"BA",X"29",X"CB",X"11",X"8F",X"F2",X"0D",X"07",X"19",X"10",X"F6",X"F1",
		X"B4",X"67",X"C1",X"C3",X"61",X"05",X"C5",X"7C",X"AA",X"E6",X"80",X"F5",X"CB",X"BA",X"CB",X"BC",
		X"7A",X"B3",X"28",X"29",X"E5",X"AF",X"4F",X"47",X"04",X"ED",X"52",X"38",X"06",X"CB",X"13",X"CB",
		X"12",X"30",X"F5",X"A7",X"E1",X"ED",X"52",X"30",X"01",X"19",X"3F",X"CB",X"11",X"17",X"CB",X"1A",
		X"CB",X"1B",X"10",X"F1",X"47",X"F1",X"B0",X"67",X"69",X"C1",X"C3",X"61",X"05",X"3E",X"1E",X"CD",
		X"88",X"00",X"3E",X"46",X"CD",X"88",X"00",X"7A",X"FE",X"3C",X"CA",X"93",X"01",X"1B",X"1A",X"FE",
		X"1E",X"20",X"FA",X"13",X"CD",X"AC",X"02",X"C3",X"93",X"01",X"80",X"45",X"4E",X"44",X"DE",X"52",
		X"45",X"4D",X"E0",X"47",X"4F",X"53",X"55",X"42",X"E2",X"43",X"4C",X"45",X"41",X"52",X"E4",X"49",
		X"46",X"E6",X"54",X"48",X"45",X"4E",X"D1",X"49",X"4E",X"50",X"55",X"54",X"E8",X"50",X"52",X"49",
		X"4E",X"54",X"EA",X"52",X"45",X"54",X"55",X"52",X"4E",X"EC",X"4C",X"4F",X"41",X"44",X"F6",X"4C",
		X"45",X"54",X"F4",X"53",X"41",X"56",X"45",X"F8",X"47",X"4F",X"54",X"4F",X"EE",X"49",X"4E",X"28",
		X"D9",X"4F",X"55",X"54",X"FC",X"42",X"59",X"54",X"45",X"DD",X"52",X"55",X"4E",X"F0",X"4C",X"49",
		X"53",X"54",X"F2",X"4E",X"45",X"57",X"FE",X"50",X"45",X"45",X"4B",X"28",X"D7",X"50",X"4F",X"4B",
		X"45",X"FA",X"52",X"4E",X"44",X"28",X"DA",X"4F",X"52",X"D6",X"41",X"4E",X"44",X"D2",X"93",X"01",
		X"87",X"03",X"95",X"03",X"D0",X"03",X"79",X"03",X"9B",X"03",X"C0",X"03",X"98",X"03",X"54",X"03",
		X"35",X"03",X"E2",X"02",X"D6",X"03",X"00",X"08",X"03",X"08",X"ED",X"03",X"00",X"04",X"71",X"01"
	);
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
