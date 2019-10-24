classdef WingT
	%WingT Holds shape and size data for the wing
	properties (Dependent)
		c
		b
    end
    properties (SetAccess=private)
        AR
        S
        e
        K
    end
    properties(SetAccess=private, Hidden)
        p_c
		p_b
    end
	methods
        function obj = WingT(chord, span)
            obj.p_c = chord;
            obj.p_b = span;
            obj = obj.evaluate();
        end
        function val = get.c(obj)
            val = obj.p_c;
        end
        function obj = set.c(obj, val)
            obj.p_c = val;
            obj = obj.evaluate();
        end
        function val = get.b(obj)
            val = obj.p_b;
        end
        function obj = set.b(obj, val)
            obj.p_b = val;
            obj = obj.evaluate();
        end
        
    end
    methods (Access=private, Hidden)
        function obj = evaluate(obj)
            obj.S = obj.p_c * obj.p_b;
            obj.AR = obj.p_b / obj.p_c;
            obj.e = 1.78*(1-0.045*obj.AR^.68)-.64;
            obj.K = 1/(pi*obj.e*obj.AR);
        end
    end
end

