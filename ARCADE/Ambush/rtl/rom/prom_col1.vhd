library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity prom_col1 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of prom_col1 is
	type rom is array(0 to  255) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"40",X"D2",X"1B",X"FF",X"40",X"00",X"37",X"38",X"40",X"07",X"FF",X"F8",X"00",X"F0",X"3F",X"07",
		X"00",X"38",X"10",X"FF",X"00",X"F0",X"03",X"2E",X"00",X"43",X"1F",X"76",X"00",X"E0",X"F6",X"36",
		X"00",X"00",X"2F",X"FF",X"40",X"FF",X"57",X"1E",X"00",X"FF",X"ED",X"FF",X"40",X"37",X"17",X"F1",
		X"00",X"C3",X"80",X"FF",X"00",X"E8",X"07",X"FF",X"00",X"3F",X"BB",X"59",X"00",X"07",X"00",X"FF",
		X"40",X"D2",X"1B",X"FF",X"40",X"00",X"37",X"38",X"40",X"07",X"FF",X"F8",X"00",X"A4",X"07",X"00",
		X"FF",X"40",X"1C",X"5A",X"A8",X"C7",X"00",X"3F",X"00",X"43",X"1F",X"76",X"00",X"E0",X"F6",X"36",
		X"00",X"00",X"2F",X"FF",X"00",X"FF",X"FF",X"07",X"07",X"C7",X"00",X"3F",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"07",
		X"40",X"D2",X"1B",X"FF",X"40",X"00",X"37",X"38",X"40",X"07",X"FF",X"F8",X"00",X"A4",X"07",X"00",
		X"FF",X"40",X"1C",X"5A",X"A8",X"C7",X"00",X"3F",X"00",X"43",X"1F",X"76",X"00",X"E0",X"F6",X"36",
		X"00",X"00",X"2F",X"FF",X"00",X"07",X"FF",X"FF",X"FF",X"C7",X"00",X"3F",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"07",
		X"40",X"D2",X"1B",X"FF",X"40",X"00",X"37",X"38",X"40",X"07",X"FF",X"F8",X"00",X"AC",X"07",X"00",
		X"FF",X"40",X"1C",X"5A",X"A8",X"C7",X"00",X"3F",X"00",X"43",X"1F",X"76",X"00",X"E0",X"F6",X"36",
		X"00",X"00",X"2F",X"FF",X"00",X"FF",X"07",X"FF",X"07",X"C7",X"00",X"3F",X"03",X"02",X"FF",X"28",
		X"18",X"10",X"FF",X"05",X"07",X"06",X"FF",X"04",X"38",X"30",X"FF",X"20",X"C0",X"80",X"FF",X"40");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
