library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;				

entity LogicayControl is
generic (
	Nbits		:integer;		--bits del pulso
	Nbus		:integer;		--bits del bus de datos
	Naddr		:integer;		--bits del bus de direcciones
											
	Mram		:integer;		--Nro de pulsos de clkpll para el we y re
	Mdiv_RW		:integer;		--div fcia del clkpll para el barrido de w y r
	
	Mdiv_Sol	:integer;
	Mcon		:integer			--Nro de pulsos de clkpll para el tiempo de captura
	);
	
port
	(
		-- Input ports
		clk_lc			:in std_logic;								--clock 			
		Reset			:in std_logic;								--reset
		PulsoCapturado	:in std_logic;								--pulso habilitado
		PulsoMedido		:in std_logic_vector(Nbits-1 downto 0);		--pulso medido o salida del registro
		eventoN_1		:in std_logic_vector(Nbus-1 downto 0);		--RAM1 conectado al bus dato de salida
		eventoN_1RAM2	:in std_logic_vector(Nbus-1 downto 0);		--RAM2	
		txbusy			:in std_logic;

		
		-- Output ports		
		BusAddr			:out std_logic_vector((Naddr-1) downto 0);	--RAM1
		BusAddrRAM2		:out std_logic_vector((Naddr-1) downto 0);	--RAM2
		eventoN			:out std_logic_vector(Nbus-1 downto 0);		--RAM1 conectado al bus dato de entrada
		eventoNRAM2		:out std_logic_vector(Nbus-1 downto 0);		--RAM2
		SolicitaDatos	:out std_logic;
		ReadEn			:out std_logic;
--		DesSol			:out std_logic; --simulacion
--		CapturaInicio	:out std_logic; --simulacion
--		div_out_S	   :out std_logic; --simulacion
--		HabilitaS		:out std_logic; --simulacion
		TxEnable			:out std_logic;
		SELRAM			:out std_logic;
		WriteEnable		:out std_logic											

		
		);
end LogicayControl;

architecture arquitectura of LogicayControl is
-- Pulso para hablita Solicitud
signal EnSolicitud 			:std_logic:='0';
	type state_type_HS is (eReset, eOFFHS, eOnHS);
	signal state_HS   :state_type_HS;

--Divisor de Frecuencia para solicitud
signal clk_div_Sol: std_logic;
signal cuenta_div_Sol: integer range 0 to Mdiv_Sol-1 :=0;	

-- Pulso para iniciar el timer solicita datos
	type state_type_IC is (eReset, eOFF, eOn);
	signal state_inicio   :state_type_IC;
	
--señal solicita datos
signal timer_solicita 		:integer range 0 to (Mcon)-1:=0;
signal Solicita				:std_logic:='1';		
signal Captura					:std_logic:='0';		
type state_type is (eReset, eInicio, eEventos, eEnable_S, eStop);
	signal state_ct   :state_type;

--registro pulso, Lectura y escritura
signal HabilitaSolicitud 			:std_logic:='0';

-- 		*** RAM 1 ***
signal S_RAM							:std_logic:='0';
signal timer_RAM1	 		 			:integer range 0 to (Mram)-1:=0;	 
signal we			 					:std_logic:='0';
signal puntero, punteroRAM2		:integer range 0 to (2**Nbits)-1:=0;	
signal eventN_1, eventN  			:integer range 0 to (2**Nbus)-1:=0;				
signal BDataIn, BDataIn2			:std_logic_vector((Nbus-1) downto 0);
signal BAddr		 					:std_logic_vector((Naddr-1) downto 0);

-- 		*** RAM 2 ***
signal timer_RAM2	 		 			:integer range 0 to (Mram)-1:=0;
signal eventN_1RAM2, eventNRAM2	:integer range 0 to (2**Nbus)-1:=0;
signal BDataInRAM2, BDataIn2RAM2	:std_logic_vector((Nbus-1) downto 0);
signal BAddrRAM2		 				:std_logic_vector((Naddr-1) downto 0);
--signal weRAM2							:std_logic:='0';
type state_type_wr is (eReset, eDetectaPulso, eSELRAM, WriteCycle, ReadCycle,
								WriteCycleRAM2, ReadCycleRAM2,	VuelvoRegistrarP);
	signal state_wr   :state_type_wr;	
	
--Divisor de Frecuencia
signal clk_div: std_logic;
signal cuenta_div: integer range 0 to Mdiv_RW-1 :=0;	

--Barrido de Lectura y escritura de toda la memoria
signal EnTx 					:std_logic:='0';
signal DeshabilitoSolicitud 	:std_logic:='0';
--		***	RAM1	***
signal re	 					:std_logic:='1';
signal we2						:std_logic:='0';
signal puntero2					:integer range 0 to (2**Naddr)-1:=0;
signal BAddr2					:std_logic_vector((Naddr-1) downto 0);	

--		***	RAM2	***
signal puntero2RAM2				:integer range 0 to (2**Naddr)-1:=0;
signal BAddr2RAM2				:std_logic_vector((Naddr-1) downto 0);	
	
type state_type_rd is (eReset, eStartSweep, eReadSweep, eWriteSweep,
								eSend, eWait, 
								eReadSweepRAM2, eWriteSweepRAM2,
								eSendRAM2, eWaitRAM2,
								eEndSweep);
	signal state_rd   : state_type_rd;

begin

--/////////////////////////////////////////////////////////////////////////////////////////
--				Write  and Read RAM
--/////////////////////////////////////////////////////////////////////////////////////////
process (clk_lc, Reset, Solicita, PulsoCapturado)
 begin
		if (Reset = '0')  then
			state_wr <= eReset;
			puntero<=0;	
			timer_RAM1<=0;
			eventN_1<=0;
			eventN<=0;
			
			punteroRAM2<=0;
			timer_RAM2<=0;
			eventN_1RAM2<=0;
			eventNRAM2<=0;
		
		elsif (rising_edge(clk_lc)) then
			case state_wr is
				when eReset=>																					
						state_wr <= eDetectaPulso;					
								
				when eDetectaPulso=>
					if  (PulsoCapturado = '1') then 			
						state_wr <= eSELRAM;
						puntero<= to_integer(unsigned(PulsoMedido));							
					else
						state_wr <= eDetectaPulso;				
						
					end if;
				
				when eSELRAM=>
					if  (puntero >= 513) then 						--512 sería la direccion 0 de la RAM2, No la tengo en cuenta
						state_wr <= ReadCycleRAM2;					--ciclo de lectura de la RAM2
						punteroRAM2<= puntero-512;					-- siempre se cumple (puntero-512)>=0						
					else
						state_wr <= ReadCycle;						--ciclo de lectura de la RAM1					
					end if;	
					
--		***	RAM 1	***								
				when ReadCycle=>
					if timer_RAM1 = (Mram-1)  then 
						state_wr <= WriteCycle;
						timer_RAM1<=0;
						eventN<=eventN_1+1;										--bus data out RAM1
						eventN_1<= to_integer(unsigned(eventoN_1));
					else																						
						state_wr <= ReadCycle;
						timer_RAM1<=timer_RAM1+1;
						eventN_1<= to_integer(unsigned(eventoN_1));		--bus data in	RAM1
					end if;
				

				when WriteCycle=>
					if timer_RAM1 = (Mram-1) then 
						state_wr <= VuelvoRegistrarP;
						puntero<=0;
						eventN<=0;
						timer_RAM1<=0;
					else
						state_wr <= WriteCycle;
						timer_RAM1<=timer_RAM1+1;	
					end if;	
					
--		***	RAM 2	***
					when ReadCycleRAM2=>
					if timer_RAM2 = (Mram-1)  then 
						state_wr <= WriteCycleRAM2;
						timer_RAM2<=0;
						eventNRAM2<=eventN_1RAM2+1;									--bus data in RAM2
						eventN_1RAM2<= to_integer(unsigned(eventoN_1RAM2));
					else																						
						state_wr <= ReadCycleRAM2;
						timer_RAM2<=timer_RAM2+1;
						eventN_1RAM2<= to_integer(unsigned(eventoN_1RAM2));	--bus data out RAM2
					end if;
					
					when WriteCycleRAM2=>
					if timer_RAM2 = (Mram-1) then 
						state_wr <= VuelvoRegistrarP;
						puntero<=0;
						punteroRAM2<=0;
						eventNRAM2<=0;
						timer_RAM2<=0;
					else
						state_wr <= WriteCycleRAM2;
						timer_RAM2<=timer_RAM2+1;	
					end if;
					
					when VuelvoRegistrarP=>
					if  (Solicita = '1')then 
						state_wr <= eDetectaPulso;
					else
						state_wr <= VuelvoRegistrarP;	
						eventN<=0;
						eventNRAM2<=0;
					end if;	
			end case;
		end if;
	end process;
-- Output depends solely on the current state
	process (state_wr, clk_lc)
	begin
		if rising_edge(clk_lc) then
		case state_wr is
			
			when eDetectaPulso =>
									BAddr<=std_logic_vector(to_unsigned(puntero,Naddr));		--apunto en el bus direcciones
									BDataIn<=std_logic_vector(to_unsigned(0,Nbus));
									we<='0';	
									HabilitaSolicitud<='0';
									
			when eSELRAM =>
									BAddr<=std_logic_vector(to_unsigned(puntero,Naddr));		--apunto en el bus direcciones
									BDataIn<=std_logic_vector(to_unsigned(0,Nbus));
									we<='0';	
									HabilitaSolicitud<='0';
			
--			***	RAM 1	***			
			when ReadCycle =>
									we<='0';																	--Read Cycle Enable (RAM)
									BAddr<=std_logic_vector(to_unsigned(puntero, Naddr));  --sigo apunto en el bus direcciones
									BDataIn<=std_logic_vector(to_unsigned(0,Nbus));
									HabilitaSolicitud<='0';
									
								
			when WriteCycle =>
									we<='1';																	--Write Cycle Enable (RAM)
									BAddr<=std_logic_vector(to_unsigned(puntero,Naddr));	 --sigo apunto en el bus direcciones
									BDataIn<=std_logic_vector(to_unsigned(eventN,Nbus));  --guardo el nuevo dato en la RAM
									HabilitaSolicitud<='0';
				
	--			***	RAM 2	***
			when ReadCycleRAM2 =>
									we<='0';																	--Read Cycle Enable (RAM2)
									BAddrRAM2<=std_logic_vector(to_unsigned(punteroRAM2, Naddr));  --sigo apunto en el bus direcciones
									BDataInRAM2<=std_logic_vector(to_unsigned(0,Nbus));
									HabilitaSolicitud<='0';
									
								
			when WriteCycleRAM2 =>
									we<='1';																	--Write Cycle Enable (RAM2)
									BAddrRAM2<=std_logic_vector(to_unsigned(punteroRAM2,Naddr));	 --sigo apunto en el bus direcciones
									BDataInRAM2<=std_logic_vector(to_unsigned(eventNRAM2,Nbus));  --guardo el nuevo dato en la RAM
									HabilitaSolicitud<='0';

			
			when VuelvoRegistrarP =>
									BAddr<=std_logic_vector(to_unsigned(puntero,Naddr));
									BDataIn<=std_logic_vector(to_unsigned(eventN,Nbus));
									BAddrRAM2<=std_logic_vector(to_unsigned(punteroRAM2,Naddr));	 
									BDataInRAM2<=std_logic_vector(to_unsigned(eventNRAM2,Nbus));
									we<='0';	
									HabilitaSolicitud<='1';
		
			when others =>
					         BAddr<=std_logic_vector(to_unsigned(0,Naddr));
								BDataIn<=std_logic_vector(to_unsigned(0,Nbus));								
								
								BAddrRAM2<=std_logic_vector(to_unsigned(0,Naddr));
								BDataInRAM2<=std_logic_vector(to_unsigned(0,Nbus));
								we<='0';
								HabilitaSolicitud<='0';
		end case;
		end if;
	end process;

--/////////////////////////////////////////////////////////////////////////////////////////
	
----/////////////////////////////////////////////////////////////////////////////////////////
----					 timer de Enable solicitud		
----/////////////////////////////////////////////////////////////////////////////////////////
 process (clk_lc, Reset, PulsoCapturado)
 begin
		if (Reset = '0')  then
			state_HS <= eReset;
	
		elsif (rising_edge(clk_lc)) then
			case state_HS is
				when eReset=>																					
						state_HS <= eOFFHS;					
				
				when eOFFHS=>
					if (PulsoCapturado = '1') then  			--Detecta el primer pulso
						state_HS <= eOnHS;							
					else
						state_HS <= eOFFHS;
					end if;
					
				when eOnHS=>
					if (Solicita='0') then 
						state_HS <= eOFFHS;

					else
						state_HS <= eOnHS;
					end if;
					
			end case;
		end if;
	end process;
-- Output depends solely on the current state_ct
	process (state_HS, clk_lc)
	begin
		if rising_edge(clk_lc) then
		case state_HS is
			
			when eReset =>
									EnSolicitud <='0';

			when eOFFHS =>
									EnSolicitud <='0';						
			
			when eOnHS =>
									EnSolicitud <='1';			
	  			
			when others =>
									EnSolicitud <='0';			
							        
		end case;
		end if;
	end process;	
--HabilitaS<=EnSolicitud;		--simulacion

----/////////////////////////////////////////////////////////////////////////////////////////
----						 timer de solicita		
----/////////////////////////////////////////////////////////////////////////////////////////
 process (clk_lc, Reset, PulsoCapturado)
 begin
		if (Reset = '0')  then
			state_inicio <= eReset;
		
		elsif (rising_edge(clk_lc)) then
			case state_inicio is
				when eReset=>																					
						state_inicio <= eOFF;					
				
				when eOFF=>
					if (PulsoCapturado = '1') then  			--Detecta el primer pulso
						state_inicio <= eOn;							
					else
						state_inicio <= eOFF;
					end if;
					
				when eOn=>
					if (Solicita='0') then 
						state_inicio <= eOFF;
					else
						state_inicio <= eOn;	
					end if;	
					
			end case;
		end if;
	end process;
-- Output depends solely on the current state_ct
	process (state_inicio, clk_lc)
	begin
		if rising_edge(clk_lc) then
		case state_inicio is
			
			when eReset =>
									Captura <='0';

			when eOFF =>
									Captura <='0';						
			
			when eOn =>
									Captura <='1';					
	  			
			when others =>
									Captura <='0';			
							        
		end case;
		end if;
	end process;
	
--CapturaInicio<=Captura;
--/////////////////////////////////////////////////////////////////////////////////////////

----/////////////////////////////////////////////////////////////////////////////////////////
----				Divisor Solicita
----/////////////////////////////////////////////////////////////////////////////////////////
	
	devisor_Solicita: process (clk_lc, Reset)
	begin 
	
		if Reset='0' then
			cuenta_div_Sol<= 0;
				clk_div_Sol<= '0';
		elsif rising_edge (clk_lc) then
				if cuenta_div_Sol= (Mdiv_Sol-1) then		
					cuenta_div_Sol<= 0;
					clk_div_Sol<= not clk_div_Sol;
				else
					cuenta_div_Sol<=cuenta_div_Sol+1;
				end if;
		end if;
	end process;
	
--	div_out_S<=clk_div_Sol;

----//////////////////////////////////////////////////////////////////////////////////////////////
	
----/////////////////////////////////////////////////////////////////////////////////////////
----						tiempo solcita datos			
----/////////////////////////////////////////////////////////////////////////////////////////
 process (clk_div_Sol, Reset, Captura)
 begin
		if (Reset = '0')  then
			state_ct <= eReset;
			timer_solicita<=0;
		
		elsif (rising_edge(clk_div_Sol)) then
			case state_ct is
				when eReset=>																					
						state_ct <= eInicio;					
				
				when eInicio=>
					if (Captura = '1') then  			--Detecta el primer pulso
						state_ct <= eEventos;			--Comienza a detecta los eventos
					else
						state_ct <= eInicio;
					end if;
				
				when eEventos=>
					if timer_solicita = Mcon-1 then 
						state_ct <= eEnable_S;
						timer_solicita<=0;
					else
						state_ct <= eEventos;
						timer_solicita<=timer_solicita+1;	
					end if;
					
				
				when eEnable_S=>
					if EnSolicitud='1' then 
						state_ct <= eStop;
					else
						state_ct <= eEnable_S;	
					end if;
				
				when eStop=>												--deteine los eventos 
					if (DeshabilitoSolicitud='1')  then 				
						state_ct <= eInicio;
					else																						
						state_ct <= eStop;
					end if;
																				--leer toda la memoria e enviar resultados
			end case;
		end if;
	end process;
-- Output depends solely on the current state_ct
	process (state_ct, clk_div_Sol)
	begin
		if rising_edge(clk_div_Sol) then
		case state_ct is
			
			when eReset =>
									Solicita <='1';

			when eInicio =>
									Solicita <='1';						
			
			when eEventos =>
									Solicita <='1';			
									
			when eEnable_S =>
									Solicita <='1';			
	  			
			when eStop =>
									Solicita <='0';			--Solicita los datos y se detiene la operacion
			when others =>
									Solicita <='1';			
							        
		end case;
		end if;
	end process;
SolicitaDatos<=Solicita;
--/////////////////////////////////////////////////////////////////////////////////////////

----/////////////////////////////////////////////////////////////////////////////////////////
----				Divisor de Frecuencia Barrido de Memoria
----/////////////////////////////////////////////////////////////////////////////////////////
	
	devisor_fcia: process (clk_lc, Reset)
	begin 
	
		if Reset='0' then
			cuenta_div<= 0;
				clk_div<= '0';
		elsif rising_edge (clk_lc) then
				if cuenta_div= (Mdiv_RW-1) then		--cuenta hasta M pulsos reinicia la cuenta y envia la señal a la salida
					cuenta_div<= 0;
					clk_div<= not clk_div;
				else
					cuenta_div<=cuenta_div+1;
				end if;
		end if;
	end process;
	
--	div_out<=clk_div;

----//////////////////////////////////////////////////////////////////////////////////////////////
----		Barrido de Lectura Y escritura de toda la memoria y deja de detectar eventos - UART TX
----/////////////////////////////////////////////////////////////////////////////////////////////
 process (clk_div, Reset, Solicita, DeshabilitoSolicitud)
 begin
		if (Reset = '0')  then
			state_rd <= eReset;
			puntero2<=0;
			puntero2RAM2<=0;
			DeshabilitoSolicitud<='0';
		
		elsif (rising_edge(clk_div)) then
			case state_rd is
				when eReset=>																					
						state_rd <= eStartSweep;					
				
				when eStartSweep=>
					if (Solicita='0') and (we='0') 	then  
						state_rd <= eReadSweep;		
					else
						state_rd <= eStartSweep;
					end if;
--		***  RAM 1	***											
				when eReadSweep=>
					if (puntero2=((2**Naddr)-1))  then 
						state_rd <= eWriteSweep;	
						BAddr2<= std_logic_vector(to_unsigned(puntero2,Naddr));
						puntero2<=0;														
					else
						state_rd <= eSend;		--eSend;
						BAddr2<= std_logic_vector(to_unsigned(puntero2,Naddr));		
						puntero2<=puntero2+1;
					end if;
					
				when eSend=>
						state_rd <= eWait;
								
				when eWait=>
					if txbusy = '1' then			 						--espera mientras la transmision esta en curso
						state_rd <= eWait;
					else 													--si finalizo la transmision vuelve al estado Read
						state_rd <= eReadSweep;
					end if;	
				
				when eWriteSweep=>
					if (puntero2=((2**Naddr)-1))  then 
						state_rd <= eReadSweepRAM2;
						BAddr2<= std_logic_vector(to_unsigned(puntero2,Naddr));
						BDataIn2<=std_logic_vector(to_unsigned(0,Nbus));
						puntero2<=0;
						
					else
						state_rd <= eWriteSweep;
						BAddr2<= std_logic_vector(to_unsigned(puntero2,Naddr));		
						puntero2<=puntero2+1;
						BDataIn2<=std_logic_vector(to_unsigned(0,Nbus));			--Borro los datos en RAM1
					end if;
										
--		***  RAM 2	***			
				when eReadSweepRAM2=>
					if (puntero2RAM2=((2**Naddr)-1))  then 
						state_rd <= eWriteSweepRAM2;	
						BAddr2RAM2<= std_logic_vector(to_unsigned(puntero2RAM2,Naddr));	
						puntero2RAM2<=0;							
					else
						state_rd <= eSendRAM2;		--eSendRAM2;
						BAddr2RAM2<= std_logic_vector(to_unsigned(puntero2RAM2,Naddr));		
						puntero2RAM2<=puntero2RAM2+1;
					end if;
					
				when eSendRAM2=>
						state_rd <= eWaitRAM2;
								
				when eWaitRAM2=>
					if txbusy = '1' then			 				--espera mientras la transmision esta en curso
						state_rd <= eWaitRAM2;
					else 											--si finalizo la transmision vuelve al estado Read
						state_rd <= eReadSweepRAM2;
					end if;
					
				when eWriteSweepRAM2=>
					if (puntero2RAM2=((2**Naddr)-1))  then 
						state_rd <= eEndSweep;
						BAddr2RAM2<= std_logic_vector(to_unsigned(puntero2RAM2,Naddr));	
						BDataIn2RAM2<=std_logic_vector(to_unsigned(0,Nbus));
						puntero2RAM2<=0;
						DeshabilitoSolicitud<='1';							
					else
						state_rd <= eWriteSweepRAM2;
						BAddr2RAM2<= std_logic_vector(to_unsigned(puntero2RAM2,Naddr));		
						puntero2RAM2<=puntero2RAM2+1;
						BDataIn2RAM2<=std_logic_vector(to_unsigned(0,Nbus));			--Borro los datos en RAM2
					end if;
					
				when eEndSweep=>
					if (Solicita='1')  then 
						state_rd <= eStartSweep;	
						BAddr2<= std_logic_vector(to_unsigned(0,Naddr));
						BAddr2RAM2<= std_logic_vector(to_unsigned(0,Naddr));
						DeshabilitoSolicitud<='0';
					else
						state_rd <= eEndSweep;						
					end if;	
																								
			end case;
		end if;
	end process;
-- Output depends solely on the current state
	process (state_rd, clk_div)
	begin
		if rising_edge(clk_div) then
		case state_rd is
			
			when 	eReset =>
									re <='1';
									we2<='0';
									EnTx<='0';

			when eStartSweep =>
									 re<='1';	
									we2<='0';
									EnTx<='0';
									S_RAM<='0';
-- 	*** RAM1 ***  			
			when eReadSweep =>
									 re<='0';			--habilito lectura
									we2<='0';
									EnTx<='0';
									S_RAM<='0';			--selecciono Bus Data Out RAM1
			when eSend =>
									re<='1';
									we2<='0';	 		
									EnTx<='1';	 		--UART Enable (line TX)
									S_RAM<='0';			--selecciono Bus Data Out RAM1
			when eWait =>
									re<='1';
									we2<='0';	 		
									EnTx<='0';
									S_RAM<='0';			--selecciono Bus Data Out RAM1
			
			when eWriteSweep =>
									 re<='1';		
									we2<='1';		--habilito escritura
									EnTx<='0';
			--						S_RAM<='0';			--selecciono Bus Data Out RAM1
								
--		***RAM 2 ***									
			when eReadSweepRAM2 =>
									re<='0';				--habilito lectura
									we2<='0';
									EnTx<='0';
									S_RAM<='1';			--selecciono Bus Data Out RAM2

			when eSendRAM2 =>
									re<='1';
									we2<='0';	 		
									EnTx<='1';	 		--UART Enable (line TX)
									S_RAM<='1';			--selecciono Bus Data Out RAM2
			when eWaitRAM2 =>
									re<='1';
									we2<='0';	 		
									EnTx<='0';
									S_RAM<='1';			--selecciono Bus Data Out RAM2	
		
			when eWriteSweepRAM2 =>
									re<='1';		
									we2<='1';		--habilito escritura
									EnTx<='0';
			--						S_RAM<='1';		--selecciono Bus Data Out RAM2	
									 
			when eEndSweep =>
									re<='1';
									we2<='0'; 
									EnTx<='0';

			when others =>
									 re<='1';
									we2<='0';
									EnTx<='0';
									S_RAM<='0';
		end case;
		end if;
	end process;
--DesSol<=DeshabilitoSolicitud;
ReadEn<=re;	
TxEnable<=EnTx;
--	*** RAM 1 ***
process(Solicita, BAddr2, BAddr)	
begin			
	case Solicita  is								
			when '0'		 =>	BusAddr<=BAddr2;	--detengo los datos y leo y escribo toda la memoria
			when '1'		 =>	BusAddr<=BAddr;	--leo y escribo para gaurdar los eventos en  de memoria		
			when others	 =>	BusAddr<=std_logic_vector(to_unsigned(0,Naddr));	
	end case;
end process;

process(Solicita, BDataIn2, BDataIn)	
begin			
	case Solicita  is								
			when '0'		 =>	eventoN<=BDataIn2;	
			when '1'		 =>	eventoN<=BDataIn;		
			when others	 =>	eventoN<=std_logic_vector(to_unsigned(0,Nbus));	
	end case;
end process;

process(Solicita, we2, we)	
begin			
	case Solicita  is								
			when '0'		 =>	WriteEnable<=we2;	
			when '1'		 =>	WriteEnable<=we;		
			when others	 =>	WriteEnable<='0';
	end case;
end process;

--	*** RAM 2 ***
process(Solicita, BAddr2RAM2, BAddrRAM2)	
begin			
	case Solicita  is								
			when '0'		 =>	BusAddrRAM2<=BAddr2RAM2;	--detengo los datos y leo y escribo toda la memoria
			when '1'		 =>	BusAddrRAM2<=BAddrRAM2;		--leo y escribo para gaurdar los eventos en  de memoria		
			when others	 =>	BusAddrRAM2<=std_logic_vector(to_unsigned(0,Naddr));	
	end case;
end process;

process(Solicita, BDataIn2RAM2, BDataInRAM2)	
begin			
	case Solicita  is								
			when '0'		 =>	eventoNRAM2<=BDataIn2RAM2;	
			when '1'		 =>	eventoNRAM2<=BDataInRAM2;		
			when others	 =>	eventoNRAM2<=std_logic_vector(to_unsigned(0,Nbus));	
	end case;
end process;

SELRAM<=S_RAM;

--BusAddr<=BAddr;
--eventoN<=BDataIn;
--WriteEnable<=we;	
--/////////////////////////////////////////////////////////////////////////////////////////

end arquitectura;