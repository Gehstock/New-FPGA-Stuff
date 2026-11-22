library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity col_prom is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(5 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of col_prom is
	type rom is array(0 to  63) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"00",X"C4",X"FF",X"87",X"00",X"B0",X"FF",X"2F",X"00",X"07",X"FF",X"E0",X"00",X"86",X"FF",X"C6",
		X"00",X"07",X"3F",X"FF",X"00",X"B0",X"38",X"27",X"00",X"20",X"FF",X"27",X"00",X"A4",X"FF",X"87",
		X"00",X"58",X"A8",X"27",X"00",X"38",X"3F",X"27",X"00",X"80",X"E4",X"38",X"00",X"87",X"FF",X"07",
		X"00",X"C0",X"07",X"3F",X"00",X"1F",X"3F",X"FF",X"00",X"86",X"05",X"FF",X"00",X"C0",X"E8",X"FF");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
