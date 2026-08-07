-- Divisor de frecuencia
-- regular la presicion del contador
library ieee;
use ieee.std_logic_1164.all;

entity divisor is 

generic (
	modulo: integer	 	
								
	);


port(
	reset		:in std_logic;
	reloj		:in std_logic; 	-- frecuencia de clock de la FPGA supongo 50MHz
	div_out	:out std_logic		-- frecuencia de salida más baja que la entrada
	 );
end divisor;

architecture timer  of divisor is
	signal sal: std_logic;
	signal cuenta: integer range 0 to modulo-1 :=0;
	
begin
	devisor_fcia: process (reloj)
	begin 
	
		if reset='0' then
			cuenta<= 0;
			sal<= '0';
		elsif rising_edge (reloj) then
				if cuenta= modulo-1 then		--cuenta hasta M pulsos reinicia la cuenta y envia la señal a la salida
					cuenta<= 0;
					sal<= not sal;
				else
					cuenta<=cuenta+1;
				end if;
		end if;
	end process;
	
	div_out<=sal;
end timer;