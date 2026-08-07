library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;				

entity Mux_RAM is
generic (		 		
	Nbus:				integer			--bits bus de datos	
	);
	
port
	(
		-- Input ports
		SELRAM				:in std_logic;
		I_BusDataOut0		:in std_logic_vector((Nbus-1) downto 0);		
		I_BusDataOut1		:in std_logic_vector(Nbus-1 downto 0);
		
		--Output ports
		O_BusDataOut		:out std_logic_vector(Nbus-1 downto 0)
		);
end Mux_RAM;

architecture Mux_ARQ of Mux_RAM is
begin
----/////////////////////////////////////////////////////////////////////////////////////////
----									Mux Bus Address
----////////////////////////////////////////////////////////////////////////////////////////
 process (SELRAM, I_BusDataOut0, I_BusDataOut1)
 begin	
	if (SELRAM = '0') then				--SEL bus de datos
			O_BusDataOut <= I_BusDataOut0;
				
		else 
			O_BusDataOut <= I_BusDataOut1;
	
	end if;		
	end process;	

end Mux_ARQ;