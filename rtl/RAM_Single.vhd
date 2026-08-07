--Ram Single port
--escritura y lectura  sincronicas	
--con entrada de habilitacion activo alto	

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entidad que define los puertos del modulo
entity RAM_Single is
 generic (
    Nbus       :integer ;    --Bits por palabra 
    Naddr       :integer) ;   --Bits de las direcciones
    
    Port (
        clk  : in  std_logic;                          		 -- Señal de reloj
        we   : in  std_logic;                          		 -- Señal de escritura (write enable)
		en   : in  std_logic;                          		 -- Señal de habilitacion general
        addr : in  std_logic_vector(Naddr-1 downto 0);       -- Direccion de acceso 
        di   : in  std_logic_vector(Nbus-1 downto 0);       -- Dato de entrada 
        dou  : out std_logic_vector(Nbus-1 downto 0)        -- Dato de salida 
    );
end RAM_Single;

architecture Behavioral of RAM_Single is
    -- Definicion de la RAM como una matriz 
    type ram_type is array (0 to 2**Naddr-1) of std_logic_vector(Nbus-1 downto 0);
    signal RAM : ram_type;
    attribute keep : boolean;
	attribute keep of RAM : signal is true;
    attribute syn_ramstyle : string;
    attribute syn_ramstyle of RAM : signal is "block_ram";
    attribute syn_rw_conflict_logic       : string;
  	attribute syn_rw_conflict_logic of RAM : signal is "0"; 
    signal data_out : std_logic_vector(Nbus-1 downto 0);
begin

    -- Proceso que se ejecuta en el flanco de subida del reloj
    process(clk)
    begin
        if rising_edge(clk) then
            if en = '1' then                    				  -- Si la RAM estÃ¡ habilitada
                if we = '1' then               					  -- Si escritura estÃ¡ habilitada
                    RAM(to_integer(unsigned(addr))) <= di; 	  -- Escribe el dato en memoria
                    data_out <= di;                           -- Modo WRITE_FIRST: la salida refleja lo que se escribiÃ³
                else
                    data_out <= RAM(to_integer(unsigned(addr))); -- Si no se escribe, lee desde memoria
                end if;
            end if;
        end if;
    end process;

    -- Asignacion del dato de salida
    dou <= data_out;
end Behavioral;