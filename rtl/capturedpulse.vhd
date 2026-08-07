library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;				

entity capturedpulse is
generic (
		Nbits		:integer		--bits del contador											
	);
	
port
	(
		-- Input ports
--		Reset				:in std_logic;
		clk_s				:in std_logic;											--ingreso de la señal por el clk							   	
		Solicita			:in std_logic;
		Pulso				:in  std_logic_vector(Nbits-1 downto 0);		--pulso medido o salida del contador
		
		-- Output ports
		DataValid		:out std_logic;
		PulsoRegistrado:out std_logic_vector(Nbits-1 downto 0)		
		);
end capturedpulse;

architecture arquitectura of capturedpulse is
	
begin

--/////////////////////////////////////////////////////////////////////////////////////////
--					Captura  Pulso (Registro)
--////////////////////////////////////////////////////////////////////////////////////////


process(clk_s, Solicita, Pulso)
	variable PulsoReg_int, Pulso_int :integer range 0 to 2**Nbits-1:=0;
	begin
	Pulso_int:= to_integer(unsigned(Pulso));
		if Solicita='0' then
			PulsoReg_int:=0;
		else
			if falling_edge (clk_s) then
			PulsoReg_int:=Pulso_int;
			end if;
		end if;
		PulsoRegistrado<=std_logic_vector(to_unsigned(PulsoReg_int,Nbits));
end process;


--/////////////////////////////////////////////////////////////////////////////////////////

--/////////////////////////////////////////////////////////////////////////////////////////
--					Dato valido (Registro)
--////////////////////////////////////////////////////////////////////////////////////////


process(clk_s, Solicita, Pulso)
	variable P_int 	:integer range 0 to 2**Nbits-1:=0;
	variable DV_int	:std_logic;
	begin
		P_int:= to_integer(unsigned(Pulso));
		if Solicita='0' then
			DV_int:='0';
			elsif P_int=0 then
				DV_int:='0';
			elsif falling_edge (clk_s) then
				DV_int:='1';
		end if;
		DataValid<=DV_int;
end process;


--/////////////////////////////////////////////////////////////////////////////////////////

end arquitectura;