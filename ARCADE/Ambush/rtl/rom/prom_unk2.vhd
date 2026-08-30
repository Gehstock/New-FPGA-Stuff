library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity prom_unk2 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of prom_unk2 is
	type rom is array(0 to  255) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"46",X"26",X"70",X"FF",X"6E",X"66",X"06",X"FF",X"48",X"FE",X"72",X"FF",X"68",X"FF",X"6E",X"FF",
		X"26",X"66",X"70",X"FF",X"6E",X"66",X"06",X"FF",X"48",X"FE",X"72",X"FF",X"68",X"FF",X"6E",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"46",X"26",X"70",X"FF",X"6E",X"66",X"06",X"FF",X"48",X"DE",X"52",X"FF",X"68",X"BD",X"2E",X"FF",
		X"26",X"66",X"70",X"FF",X"6E",X"66",X"06",X"FF",X"48",X"DE",X"52",X"FF",X"68",X"BD",X"2E",X"FF",
		X"46",X"26",X"70",X"FF",X"6E",X"65",X"6E",X"FF",X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF",
		X"26",X"66",X"70",X"FF",X"6E",X"65",X"6E",X"FF",X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF",
		X"46",X"46",X"50",X"FF",X"6E",X"66",X"06",X"FF",X"48",X"FE",X"72",X"FF",X"68",X"FF",X"6E",X"FF",
		X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"46",X"26",X"70",X"FF",X"6E",X"66",X"06",X"FF",X"48",X"DE",X"52",X"FF",X"68",X"BD",X"2E",X"FF",
		X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF",
		X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF",X"48",X"FE",X"72",X"FF",X"68",X"FC",X"6E",X"FF",
		X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF",X"0C",X"0C",X"0C",X"FF");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
