module exp_lut (
    input  logic [39:0] delta_q8,
    output logic [15:0] exp_q15
);

    // One LUT step represents 1/8 in Q8 format.
    // Q8: 256 units = 1.0
    // LUT step: 32 units = 1/8
    //
    // Output format:
    // Q15: 32768 represents 1.0

    logic [7:0] lut_index;

    always_comb begin

        // Saturate before adding the rounding offset, avoiding unsigned wrap.
        // Index 64 is selected for delta >= 64*32 - 16 = 2032 Q8 units.
        if (delta_q8 >= 40'd2032)
            lut_index = 8'd64;
        else
            lut_index = (delta_q8 + 40'd16) >> 5;

        case (lut_index)

            0:  exp_q15 = 16'd32768;
            1:  exp_q15 = 16'd28918;
            2:  exp_q15 = 16'd25520;
            3:  exp_q15 = 16'd22521;
            4:  exp_q15 = 16'd19875;
            5:  exp_q15 = 16'd17539;
            6:  exp_q15 = 16'd15479;
            7:  exp_q15 = 16'd13660;
            8:  exp_q15 = 16'd12055;
            9:  exp_q15 = 16'd10638;
            10: exp_q15 = 16'd9388;
            11: exp_q15 = 16'd8285;
            12: exp_q15 = 16'd7312;
            13: exp_q15 = 16'd6452;
            14: exp_q15 = 16'd5694;
            15: exp_q15 = 16'd5025;
            16: exp_q15 = 16'd4435;
            17: exp_q15 = 16'd3914;
            18: exp_q15 = 16'd3454;
            19: exp_q15 = 16'd3048;
            20: exp_q15 = 16'd2690;
            21: exp_q15 = 16'd2374;
            22: exp_q15 = 16'd2095;
            23: exp_q15 = 16'd1849;
            24: exp_q15 = 16'd1631;
            25: exp_q15 = 16'd1440;
            26: exp_q15 = 16'd1271;
            27: exp_q15 = 16'd1121;
            28: exp_q15 = 16'd990;
            29: exp_q15 = 16'd873;
            30: exp_q15 = 16'd771;
            31: exp_q15 = 16'd680;
            32: exp_q15 = 16'd600;
            33: exp_q15 = 16'd530;
            34: exp_q15 = 16'd467;
            35: exp_q15 = 16'd412;
            36: exp_q15 = 16'd364;
            37: exp_q15 = 16'd321;
            38: exp_q15 = 16'd283;
            39: exp_q15 = 16'd250;
            40: exp_q15 = 16'd221;
            41: exp_q15 = 16'd195;
            42: exp_q15 = 16'd172;
            43: exp_q15 = 16'd152;
            44: exp_q15 = 16'd134;
            45: exp_q15 = 16'd118;
            46: exp_q15 = 16'd104;
            47: exp_q15 = 16'd92;
            48: exp_q15 = 16'd81;
            49: exp_q15 = 16'd72;
            50: exp_q15 = 16'd63;
            51: exp_q15 = 16'd56;
            52: exp_q15 = 16'd49;
            53: exp_q15 = 16'd43;
            54: exp_q15 = 16'd38;
            55: exp_q15 = 16'd34;
            56: exp_q15 = 16'd30;
            57: exp_q15 = 16'd26;
            58: exp_q15 = 16'd23;
            59: exp_q15 = 16'd21;
            60: exp_q15 = 16'd18;
            61: exp_q15 = 16'd16;
            62: exp_q15 = 16'd14;
            63: exp_q15 = 16'd12;
            64: exp_q15 = 16'd11;

            default: exp_q15 = 16'd11;

        endcase

    end

endmodule
