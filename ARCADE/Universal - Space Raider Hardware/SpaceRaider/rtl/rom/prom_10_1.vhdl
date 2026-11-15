library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity prom_10_1 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(4 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of prom_10_1 is
	type rom is array(0 to  31) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"00",X"51",X"BB",X"95",X"00",X"96",X"9B",X"B5",X"00",X"35",X"91",X"59",X"00",X"95",X"5E",X"A9",
		X"00",X"97",X"B5",X"DE",X"00",X"19",X"B5",X"43",X"00",X"DE",X"23",X"B5",X"00",X"DB",X"B1",X"5E");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
