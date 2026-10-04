library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity prom_coll_detect is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(4 downto 0);
	data : out std_logic_vector(3 downto 0)
);
end entity;

architecture prom of prom_coll_detect is
	type rom is array(0 to  31) of std_logic_vector(3 downto 0);
	signal rom_data: rom := (
		X"0",X"1",X"0",X"1",X"0",X"1",X"1",X"1",X"0",X"0",X"0",X"0",X"1",X"1",X"0",X"1",
		X"1",X"0",X"0",X"1",X"0",X"0",X"0",X"0",X"1",X"1",X"1",X"1",X"1",X"1",X"0",X"1");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
