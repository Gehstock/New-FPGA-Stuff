library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity col is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(4 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of col is
	type rom is array(0 to  31) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"60",X"80",X"7C",X"03",X"01",X"25",X"7F",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"80",X"80",X"80",X"80",X"80",X"80",X"80",X"80");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
