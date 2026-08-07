-- contador ascendente
-- con enable y clear
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;				--permite hacer conversiones de variables
use ieee.std_logic_unsigned.all;		--permite realizar operaciones binarias sin signo

entity contador is 

generic (

	Ncounter		:integer		--bits del contador
	
	);


port(
	
	enable:			in std_logic;										-- habilitacion del contador	
	clear:			in std_logic;										-- reinicio interno del contador 
	clk_cont:		in std_logic;										-- frecuencia de Clock del contador
	out_cont:		out std_logic_vector((Ncounter-1) downto 0)	   --salida del contador 
	 );
end contador;

architecture cont  of contador is
	
begin

	
process(clk_cont)
variable cuenta :integer range 0 to 2**Ncounter-1:=0;
begin
		
	if rising_edge(clk_cont) then
	
		if (clear='0' ) then
			cuenta:=0;
				
			elsif (enable ='1') and (cuenta<(2**Ncounter-1))  then
					cuenta:=cuenta+1;
						
			elsif (cuenta=(2**Ncounter-1))then
					cuenta:=cuenta;
		end if;		
	end if;
		
	out_cont<= std_logic_vector(to_unsigned(cuenta,Ncounter));
end process;
		
end cont;