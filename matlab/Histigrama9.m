%% ---------------- Script de lectura UART desde FPGA (maxWait = 30 min) ----------------
close all
clear
clc

%% -------------------- Parámetros que podés ajustar -------------------------
serialPort     = 'COM5';    % puerto serie
baudRate       = 115200;    % baudios
dataGoal       = 1024;      % bytes esperados (tamaño total del la direccion RAM)
InputBuf       = 8192;      % tamaño buffer de entrada (bytes)
maxWaitMinutes = 30;        % <- TIEMPO MÁXIMO A ESPERAR (minutos)
maxIdleTime    = 1.0;       % segundos: tiempo de inactividad tras comenzar la ráfaga
AgrupandoBines = 20;        % agrupacion de bines
clk            = 10e-9;     % periodo del clk (s) para eje tiempo

% ---------------------- Crear y abrir puerto serie -------------------------
s = serial(serialPort, 'BaudRate', baudRate);

% Aumentar buffer para ráfagas largas
s.InputBufferSize = max(InputBuf, s.InputBufferSize);


set(s, 'Terminator', 'LF'); % para version R2013a

% Timeout por si se usa fread bloqueante en otra parte
s.Timeout = 10;

% Abrir puerto dentro de try/catch para asegurar cierre si falla
try
    fopen(s);
catch err
    error('No se pudo abrir el puerto %s: %s', serialPort, err.message);
end

% Limpiar cualquier dato residual que hubiese quedado en el buffer
if exist('flushinput','file')
    flushinput(s);
end

fprintf('Puerto %s abierto. Esperando hasta %d minutos por inicio de transmisión...\n', serialPort, maxWaitMinutes);

% -------------------- Esperar el primer byte (con timeout global) ----------
tStart = tic;
maxWaitSeconds = maxWaitMinutes * 60;
firstByteArrived = false;

while toc(tStart) < maxWaitSeconds
    if s.BytesAvailable > 0
        firstByteArrived = true;
        break;
    end
    pause(0.2);  %  para no saturar CPU mientras espera
end

if ~firstByteArrived
    %SI No llegó nada en el tiempo máximo: cerrar y salir limpiamente
    warning('No llegó ningún byte en %d minutos. Abortando lectura.', maxWaitMinutes);
    fclose(s); delete(s); clear s;
    return;
end

% -------------------- Preasignar buffer y leer lo que haya ahora ----------
dataMatrix = zeros(dataGoal,1,'uint8');   % prealocación
pos = 1;

if s.BytesAvailable > 0
    aLeer = min(s.BytesAvailable, dataGoal - pos + 1);
    chunk = fread(s, aLeer, 'uint8');
    L = numel(chunk);
    if L>0
        dataMatrix(pos:pos+L-1) = uint8(chunk);
        pos = pos + L;
        fprintf('Bytes recibidos: %d / %d\n', pos-1, dataGoal);
    end
end

% -------------------- Leer resto hasta dataGoal o timeout de inactividad ---
lastReceiveTime = tic;
while pos <= dataGoal
    if s.BytesAvailable > 0
        bytesFaltantes = dataGoal - pos + 1;
        disponibles = s.BytesAvailable;
        aLeer = min(disponibles, bytesFaltantes);
        chunk = fread(s, aLeer, 'uint8');
        L = numel(chunk);
        if L>0
            dataMatrix(pos:pos+L-1) = uint8(chunk);
            pos = pos + L;
            lastReceiveTime = tic;                   % reiniciar inactividad
            fprintf('Bytes recibidos: %d / %d\n', pos-1, dataGoal);
        end
    else
        % si no hay bytes disponibles, verifico inactividad
        if toc(lastReceiveTime) > maxIdleTime
            warning('Timeout por inactividad: recibió %d de %d bytes.', pos-1, dataGoal);
            break;
        end
        pause(0.001);
    end
end

% -------------------- Cerrar puerto y limpiar ------------------------------
fclose(s);
delete(s);
clear s;

% -------------------- Ajustar vector recibido ------------------------------
if pos <= dataGoal
    N = pos-1;
    dataMatrix = dataMatrix(1:N);
else
    N = dataGoal;
end
fprintf('Lectura final: %d bytes.\n', N);

if N == 0
    warning('No se recibieron bytes. No hay datos para graficar.');
    return;
end

% -------------------- Agrupamiento por bines (opcional) --------------------
if AgrupandoBines < 1 || AgrupandoBines ~= floor(AgrupandoBines)
    error('AgrupandoBines debe ser entero positivo.');
end
numBins = floor(N / AgrupandoBines);
if numBins < 1
    warning('No hay suficientes muestras (%d) para el FactorBineado=%d. Se omite agrupamiento.', N, AgrupandoBines);
    doBinning = false;
else
    doBinning = true;
    binnedData = zeros(numBins,1);
    binnedIdx  = zeros(numBins,1);
    for k = 1:numBins
        idxStart = (k-1)*AgrupandoBines + 1;
        idxEnd   = k*AgrupandoBines;
        binnedData(k) = sum(double(dataMatrix(idxStart:idxEnd)));
        binnedIdx(k)  = idxStart + AgrupandoBines/2 - 1;  % centro (0-based)
    end
    binnedTime = binnedIdx * clk;
end

%& -------------------- Gráficos ---------------------------------------------
%% Gráfico 1: muestra a muestra
figure;
indices = 0:(N-1);
bar(indices, double(dataMatrix), 'FaceColor', [0.2 0.6 0.8]);
title(sprintf('Multicanal (muestra a muestra) - %d bytes recibidos', N));
xlabel(sprintf('Muestras (0 a %d)', N-1));
ylabel('Counts');
xlim([0 N-1]);
ylim([0 260]);
grid on;

% =============== Guardando la figura como imagen ====================
filename = 'detector_a_2_0cm_30min(1).png';     %detector_a_2_0cm_30min
saveas(gcf, filename);

%% Gráfico 2 y 3: solo si hubo agrupamiento válido
if doBinning
    figure;
    bar(binnedIdx, binnedData, 'FaceColor', [0.8 0.4 0.2]);
    title(sprintf('Multicanal (Agrupando Bines = %d)', AgrupandoBines));
    xlabel('(muestra)');
    ylabel('Counts');
    xlim([binnedIdx(1)-AgrupandoBines/2, binnedIdx(end)+AgrupandoBines/2]);
    ylim([0, max(binnedData)*1.1]);
    grid on;

% =============== Guardando la figura como imagen ====================
    filename = 'detector_a_2_0cm_30min(2).png';
    saveas(gcf, filename);  
    
    figure;
    bar(binnedTime, binnedData, 'FaceColor', [0.4 0.6 0.9]);
    title(sprintf('Multicanal vs Tiempo (Bines = %d)', AgrupandoBines));
    xlabel('Tiempo (s)');
    ylabel('Counts');
    xlim([binnedTime(1)-(AgrupandoBines/2)*clk, binnedTime(end)+(AgrupandoBines/2)*clk]);
    ylim([0, max(binnedData)*1.1]);
    grid on;
    
% =============== Guardando la figura como imagen ====================
    filename = 'detector_a_2_0cm_30min(3).png';
    saveas(gcf, filename);    
end


