--/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--M pulsos de clock
--ton= M*clk

--Divisor de frecuencia M	(fpll/2*fout)

--Xseg=(Mdiv_Sol*clk_div_Sol)
--	     1seg  <=> 500000 pulsos clk100M
--	     2seg  <=> 1000000 pulsos clk100M
--1min  <=> 60seg  <=> 30000000 pulsos clk100M
--10min <=> 600seg <=> 300000000 pulsos clk100M
--15min <=> 900seg <=> 450000000 pulsos clk100M
--20min <=> 1200seg <=> 600000000 pulsos clk100M
--30min <=> 1800seg <=> 900000000 pulsos clk100M
--/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--Top Level
-- Multicanal 1024 bines

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;		--permite realizar operaciones binarias sin signo
use ieee.numeric_std.all;				--permite hacer conversiones de variables

entity LecturaPulsos is
generic (				
--	Tiempo de Captura
	Mdiv_Sol	:integer:=100;		-- Mdiv_Sol=fin/2*fout= (100M)/2*(500k)=100 ==> clk_div_Sol=2useg
	McapturaOn	:integer:=900000000;	-- 60seg=(30000000*2useg) 

--Mide Pulso
	Nbits	:integer:=10;		-- bits del PULSO (Nro Bines y bus direcc)
	
--RAM	
	Nbus	:integer:=8;	 	-- bits bus de datos y altura de los bines
	Naddr	:integer:=9;		-- bits bus de direcciones	 
	Mre_we	:integer:=4;		-- 4 son 80nseg min  tiempo de lectura y escritura 
	MdivRW	:integer:=3;		-- 3 son 60nseg, min tiempo de barrido de lectura y escritura
		
--Relay On Off
	MdelayOn	:integer:=210;		--500nseg=(50*10nseg)
	MdelayOff	:integer:=100;		--1000nseg=(100*10nseg)
	
--UART
	Muart			:integer:=868		--(100MHz) / (115200Hz) = 868
	);


port(

	clk12MHz	:in  std_logic;			-- frecuencia EDU CIAA FPGA 
	senial		:in  std_logic;			--señal acondicionada, se quiere medir la duracion del tiempo
	reset		:in  std_logic;
	Led1_Pll 	:out std_logic;	
	DescargaC 	:out std_logic;		
	OnOffRampa	:out std_logic;
	Txout		:out std_logic
	
	 );
end LecturaPulsos;

architecture toplevel  of LecturaPulsos is	
--Señales de habilitacion y Reset
	signal RST, SolicitaD,DValido,EnablePulse	:std_logic;
	
--Señales Contador y Registro (mide pulso)
	signal pulsoC, PRegistrado						:std_logic_vector((Nbits-1) downto 0);

-- Señales RAM1
	signal writeEn, readEn,WandR, Sel_RAM		:std_logic;	
	signal EventosN_1, EventosN					:std_logic_vector((Nbus-1) downto 0);		
	signal baddr										:std_logic_vector((Naddr-1) downto 0);

-- Señales RAM2
--	signal writeEnRAM2, WandRRAM2		:std_logic;	
	signal EventosN_1RAM2, EventosNRAM2	:std_logic_vector((Nbus-1) downto 0);		
	signal baddrRAM2					:std_logic_vector((Naddr-1) downto 0);
	
-- Señales UART Tx	
	signal EnTx,Txbusy,EndTx			:std_logic;
	signal BDataOut						:std_logic_vector((Nbus-1) downto 0);
-- Señales On off
	signal CargaRampa, Desc_C			:std_logic;
	
--simulacion
--	signal capture							:std_logic;
--	signal Div_sol							:std_logic;
--	signal HSolicitud						:std_logic;
--	signal DSol								:std_logic;  
--	signal senial							:std_logic;

-- Lineas internas del PLL de 100.5MHz
	signal clk100M 	:std_logic;	-- fcia del PLL 100MHz (salida del PLL)
	signal locked 	:std_logic;	-- Indicador de PLL estable
	signal O_pllcore:std_logic;

-- Declarar componente PLL de 100.5MHz
	component PLL100_1 is
  	  port (REFERENCECLK   		:in  std_logic; 	-- Clock de entrada
  	 		RESET				:in  std_logic;
			PLLOUTCORE			:out std_logic;
          	PLLOUTGLOBAL 		:out std_logic;   	-- Clock de salida
         	LOCK     			:out std_logic); 	-- PLL enganchado
	end component PLL100_1;
	
-- Lineas internas del PLL de 100MHz
--	signal clk100M_2 	:std_logic;	-- fcia del PLL 100MHz (salida del PLL)
--	signal locked2 		:std_logic;	-- Indicador de PLL estable
--	signal O_pllcore2	:std_logic;
--	
---- Declarar componente PLL de 100.5MHz
--	component PLL100_2 is
--  	  port (REFERENCECLK   	:in  std_logic; 	-- Clock de entrada
--  	 		RESET			:in  std_logic;
--			PLLOUTCORE		:out std_logic;
--          	PLLOUTGLOBAL 	:out std_logic;   	-- Clock de salida
--         	LOCK     		:out std_logic); 	-- PLL enganchado
--	end component PLL100_2;

begin
-----------------------------------------------------------------------------------------------------------------------
--------------        conectando los componentes        ---------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------
--------------        genero señal de pruba       ---------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------
--Senial11: 	entity work.divisor generic map(500) port map (reset,clk100M, senial);	-- fin/2*fout	200 2useg
--------------------------------------------------------------------------------------------------------------------
	
	RST<=reset and senial;		--Si reset=0 reinicio / Solicita=0 paro la medicion, lectura y tx de datos
		
PLL1_100:PLL100_1 port map (REFERENCECLK  => clk12MHz, 
									RESET=> reset, 
							  PLLOUTCORE => O_pllcore,
							PLLOUTGLOBAL => clk100M, 
									LOCK => locked);
									
--PLL2_100:PLL100_2 port map (REFERENCECLK  => clk12MHz, 
--									RESET=> reset, 
--							  PLLOUTCORE => O_pllcore2,
--							PLLOUTGLOBAL => clk100M_2, 
--									LOCK => locked2);


										          		     		      	 		   		 
MidePulso :entity work.contador generic map (Nbits) 	--bits del pulso																																
									port map (RST, 		--En
											 RST, 		--clear
											 clk100M,	--clk_cont																	 
											 pulsoC);	--out_cont

																	 
																	 
CP :entity work.capturedpulse generic map (Nbits) 		--bits del pulso
									port map (senial, 	--clk señal			
											SolicitaD,
											pulsoC,			--salida del contador	
											DValido,			--data Valid
											PRegistrado );	--Pulso Registrado
															

EnablePulse<=DValido and SolicitaD;											          			   		     											 			
LC	:entity work.LogicayControl	generic map(Nbits, 	--bits del pulso
											Nbus,				--bits bus de datos
											Naddr,			--bits bus de direcc
											Mre_we,			--tiempo RE y WE
											MdivRW,			--barrido r and w
											Mdiv_Sol,
											McapturaOn)																																
								 port map (
								 --Input
										 clk100M, 			--clk
											 reset, 			--Reset
											 EnablePulse,		--Pulso capturado
											 PRegistrado,		--pulso medido
											 EventosN_1,		--evento anterior (Data out RAM1)
											 EventosN_1RAM2,	--evento anterior (Data out RAM2)
											Txbusy,				--indica si la transmision esta en curso
								--Output	
											 baddr,				--Apunto al bus  address RAM1
											 baddrRAM2,			--Apunto al bus  address RAM2
											 EventosN,			--evento actual (data in RAM1)
											 EventosNRAM2,		--evento actual (data in RAM2)
											 SolicitaD,			--detiene la operacion y muestra los resultados
											 readEn,			--re
--											 DSol,				--Deshabilito Solicitud (SIMULACION)
--											 Capture,			--SIMULACION
--											 Div_sol,			--SIMULACION
--											 HSolicitud,		--SIMULACION
											 EnTx,				--Enable TX
											 Sel_RAM,			-- SEL RAM
											 writeEn);			--we 
															
WandR<=writeEn and readEn;																	 
Inst_RAM_1:entity work.RAM_Single generic map(Nbus, --Nbus
												Naddr) 			--Naddr																	
										port map (clk100M, 		--clk													
												WandR, 				--we
												'1',
												baddr, 				--addr
												EventosN, 			--data_in	
												EventosN_1);		--data_out
																																	 
Inst_RAM_2:entity work.RAM_Single generic map(Nbus, 			--Nbus
												Naddr) 				--Naddr																		
										port map (clk100M, 		--clk													
													WandR, 			--we
													'1',
												baddrRAM2, 			--waddr
												EventosNRAM2, 		--data_in	
												EventosN_1RAM2);	--data_out

															
MuxDataOut :entity work.Mux_RAM 	generic map (Nbus) 				--bits bus de datos																															
										port map (Sel_RAM, 			--Sel RAM
												 EventosN_1, 		--Bus de datos RAM0 (entrada)
												 EventosN_1RAM2,	--Bus de datos RAM1 (entrada)																 
												 BDataOut);			--Bus de datos (salida)		
															
UTx	:entity work.UART_Tx	generic map (Muart,
										Nbus) 																	
							 port map (clk100M,  	--clk	
										EnTx,		--habilitacion de Tx
										BDataOut,	--Datos a transmitir	(in)
										Txbusy,		--Transmision en curso
										Txout,		-- salida serie (Tx)
										EndTx);		--fin de transmision	
																	
ON_OFF:entity work.RelayOnOff	generic map (MdelayOn,
											MdelayOff)
								port map (
										reset,			--reset
										clk100M,  	--clk
										senial,			--se?al
										SolicitaD,		-- detiene on off  
										Desc_C,			--out2
										CargaRampa		--out   on off
										);
											
----------------------------------------------------------------------------------------------------------------------	
OnOffRampa<=CargaRampa;
Led1_Pll <=locked;
DescargaC<=Desc_C;

end toplevel;