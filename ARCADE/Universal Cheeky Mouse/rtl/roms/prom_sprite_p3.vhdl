library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity prom_sprite_p3 is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(4 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of prom_sprite_p3 is
	type rom is array(0 to  31) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"88",X"FF",X"FB",X"F9",X"88",X"FD",X"FB",X"FF",X"88",X"FC",X"FB",X"FF",X"88",X"FB",X"FB",X"F9",
		X"88",X"FE",X"FB",X"FF",X"88",X"FA",X"FB",X"FF",X"88",X"F9",X"FB",X"FF",X"88",X"FD",X"FA",X"FB");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
