function afName = getNaca(nacaSpec)
afNums = sum(nacaSpec .* [1000,100,1], 2);
afName(length(afNums)) = "";
for idx = 1:length(afNums)
    system(char(sprintf("python nacagen.py %04d 0", afNums(idx))));
    afName(idx) = sprintf("NACA%04d-xf", afNums(idx));
end
end