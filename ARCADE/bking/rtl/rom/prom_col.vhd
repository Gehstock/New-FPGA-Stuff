library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity prom_col is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(8 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of prom_col is
	type rom is array(0 to  511) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"9A",X"00",X"9F",X"5B",X"28",X"07",X"C0",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"DB",
		X"3F",X"3F",X"3F",X"3F",X"3F",X"3F",X"3F",X"DB",X"DB",X"DB",X"DB",X"DB",X"DB",X"DB",X"DB",X"DB",
		X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",
		X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",
		X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",
		X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"BE",X"00",X"00",X"5B",X"28",X"07",X"C0",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"DB",
		X"3F",X"3F",X"3F",X"3F",X"3F",X"3F",X"3F",X"DB",X"DB",X"DB",X"DB",X"DB",X"DB",X"DB",X"DB",X"DB",
		X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",
		X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",
		X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",
		X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"9A",X"00",X"9F",X"5B",X"28",X"07",X"C0",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"DB",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"DB",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"DB",
		X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",
		X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",
		X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",
		X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"BE",X"00",X"00",X"5B",X"28",X"07",X"C0",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"DB",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"DB",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"DB",
		X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",
		X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",
		X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",
		X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",X"87",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
