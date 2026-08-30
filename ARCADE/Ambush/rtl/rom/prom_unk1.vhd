library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity prom_unk1 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of prom_unk1 is
	type rom is array(0 to  255) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"6F",X"AF",X"2F",X"FF",X"4F",X"CF",X"0E",X"FF",X"7F",X"9F",X"9F",X"FF",X"9F",X"9F",X"FF",X"FF",
		X"8F",X"2B",X"8F",X"FF",X"4F",X"CF",X"0E",X"FF",X"7F",X"3B",X"9F",X"FF",X"9F",X"9F",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"6F",X"AF",X"2F",X"FF",X"4F",X"CF",X"0E",X"FF",X"3B",X"9F",X"9F",X"FF",X"9F",X"9F",X"1D",X"FF",
		X"8F",X"2B",X"8F",X"FF",X"4F",X"CF",X"0E",X"FF",X"3B",X"9F",X"9F",X"FF",X"9F",X"9F",X"1D",X"FF",
		X"6F",X"AF",X"2F",X"FF",X"47",X"DF",X"1E",X"FF",X"3B",X"1B",X"9B",X"FF",X"3B",X"1B",X"9B",X"FF",
		X"8F",X"2B",X"8F",X"FF",X"47",X"DF",X"1E",X"FF",X"3B",X"1B",X"9B",X"FF",X"3B",X"1B",X"9B",X"FF",
		X"8F",X"47",X"8F",X"FF",X"4F",X"CF",X"8F",X"FF",X"7F",X"9F",X"9F",X"FF",X"9F",X"9F",X"9F",X"FF",
		X"3B",X"1B",X"9B",X"FF",X"3B",X"1B",X"9B",X"FF",X"3B",X"1B",X"9B",X"FF",X"3B",X"1B",X"9B",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"6F",X"AF",X"2F",X"FF",X"4F",X"CF",X"0E",X"FF",X"3B",X"9F",X"9F",X"FF",X"9F",X"9F",X"1F",X"FF",
		X"3B",X"1B",X"9B",X"FF",X"3B",X"1B",X"9B",X"FF",X"3B",X"1B",X"9B",X"9B",X"3B",X"1B",X"9B",X"FF",
		X"3B",X"1B",X"9B",X"FF",X"3B",X"1B",X"9B",X"FF",X"3B",X"9F",X"9F",X"FF",X"9B",X"8F",X"0F",X"FF",
		X"3B",X"1B",X"9B",X"FF",X"3B",X"3B",X"1F",X"FF",X"3B",X"1B",X"9B",X"FF",X"3B",X"1B",X"9B",X"FF");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
