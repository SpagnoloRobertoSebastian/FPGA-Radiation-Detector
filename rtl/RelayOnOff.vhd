--Supongo que el tiempo minimo de separacion entre dos pulsos gaussiano es de 1useg
-- Bloque ON OFF
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;				

entity RelayOnOff is

generic (
	MdelayOn			:integer;
	MdelayOff		:integer
	);
	
port
	(
		-- Input ports
		Reset				:in std_logic;										-- reinicio interno del contador 
		clk				:in std_logic;										--clock 100MHz
		senial			:in std_logic;										--ingreso de la señal por el clk							   	
		Stop_OnOff		:in std_logic;										--detiene PWM Solicita
	
		-- Output ports	
		desc_C			:out std_logic;
		OnOFF				:out std_logic
				
		);
end RelayOnOff;

architecture arquitectura of RelayOnOff is

--Tiempo PWM
 signal OnOff_int,desc_Cint		:std_logic:='0';
 signal timer_delayOn	:integer range 0 to (MdelayOn)-1:=0; 
 signal timer_delayOff	:integer range 0 to (MdelayOff)-1:=0; 
 type state_type is (eReset, eON, eDelayOff, eOFF, eDelayOn);
	signal state_PWM   : state_type;
	
begin

--/////////////////////////////////////////////////////////////////////////////////////////
--							Relay		ON Off
--/////////////////////////////////////////////////////////////////////////////////////////
	
	 process (clk, Reset, Stop_OnOff)
 begin
		if (Reset = '0') or (Stop_OnOff='0') then
			state_PWM <= eReset;
		
		elsif (rising_edge(clk)) then
			case state_PWM is
				when eReset=>																					
						state_PWM <= eOFF;				
						
				when eOFF=>
					if (senial = '1')  then 				--si señal es 1, primer cruce
						state_PWM <= eDelayOff;			
					else																						
						state_PWM <= eOFF;
					end if;		
		
		when eDelayOff=>
					if (timer_delayOff= MdelayOff-1) then 		--Reinicio	
						state_PWM <= eON;
						timer_delayOff<=0;
					else
						state_PWM <= eDelayOff;
						timer_delayOff<=timer_delayOff+1;
					end if;		
					
				when eON=>
					if (senial = '0') then 					--si señal es 0 segundo cruce
						state_PWM <= eDelayOn;
					else
						state_PWM <= eON;
					end if;		

				when eDelayOn=>
					if (timer_delayOn= MdelayOn-1) then 		--Reinicio	
						state_PWM <= eOFF;
						timer_delayOn<=0;
					else
						state_PWM <= eDelayOn;
						timer_delayOn<=timer_delayOn+1;
					end if;
			end case;
		end if;
	end process;
-- Output depends solely on the current state
	process (state_PWM)
	begin
		if rising_edge(clk) then
		case state_PWM is
			
			when eOFF =>
									OnOff_int<='0';			--no cargo al capacitor	
									desc_Cint<='1';			--descargo C (rampa descendente)
			when eDelayOff =>
									OnOff_int<='0';			--no cargo al capacito 		
									desc_Cint<='1';
			when eON =>
									OnOff_int<='1';			--cargo al capacito (rampa ascendente)
									desc_Cint<='0';
			when eDelayOn =>
									OnOff_int<='1';			--cargo al capacito (rampa)	
								   desc_Cint<='0';
			when others =>
									OnOff_int<='0';	
									desc_Cint<='0';
							          
		end case;
		end if;
	end process;
	
OnOFF<=OnOff_int;		
desc_C<=desc_Cint;	
					
end arquitectura;