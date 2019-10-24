function Re = Reynolds(FreeVelocityms, WingChordm, AirDensity, AirDymVis, SigFigs)
    %Reynolds Calculates Reynolds number
    %   FreeVelocityms, WingChordm, AirDensity, AirDymVis
	Re = round((AirDensity.*FreeVelocityms.*WingChordm)./AirDymVis, SigFigs, 'significant');
end