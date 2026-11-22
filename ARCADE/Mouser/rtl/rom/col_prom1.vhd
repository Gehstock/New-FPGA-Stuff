library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity col_prom1 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(4 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of col_prom1 is
	type rom is array(0 to  31) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"00",X"C4",X"FF",X"87",X"00",X"B0",X"FF",X"2F",X"00",X"07",X"FF",X"E0",X"00",X"86",X"FF",X"C6",
		X"00",X"07",X"3F",X"FF",X"00",X"B0",X"38",X"27",X"00",X"20",X"FF",X"27",X"00",X"A4",X"FF",X"87");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
