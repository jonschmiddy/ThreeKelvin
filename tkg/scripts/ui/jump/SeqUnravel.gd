class_name SeqUnravel
extends JumpSequence

## R9 UNRAVEL ("R9 goes crazy", Jon, Nov 10). The drive pulses, then the hull comes apart plate
## by plate into ribbons of aurora light that whip forward over and under what is left, draw
## taut into a corona ahead and snap away, leaving curtains of afterglow that drift up and fade.
## The clock and every curve are the approved film's (tk-scratch/jump-drive/round3/_r9/r9.py).
## Why: docs/why/SeqUnravel.md#unravel

const SHADER := preload("res://shaders/jump/jump_r9.gdshader")
const THREADS := preload("res://shaders/jump/jump_r9_threads.gdshader")
const MATTER := preload("res://shaders/jump/jump_r9_matter.gdshader")

const T_WAKE := 0.6
const T_UNR := 2.3
const T_DONE := 5.05
const T_TAUT := 5.3
const T_HOLD := 5.85
const T_ZIP := 6.08
const T_SNAP := 6.15
const STR := 1.75
const STEP := 0.55
## The film's hull: 236 x 93, its plates split at these columns, its middle row 50.
const FILM_W := 236.0
const FILM_H := 93.0
const PE := [0.0, 33.0, 57.0, 79.0, 95.0, 111.0, 151.0, 186.0, 237.0]
## The corona stood 446 px ahead of the nose, 22 px above the hull's middle row.
const VP_AHEAD := 446.0
## The light buffers hold light pre-scaled to fit 8 bits: lines, curtains, afterglow, ghost.
const K_LINE := 0.25
const K_CURT := 2.0
const K_LAG := 0.5
const K_GHOST := 0.25
const MINT := Color(0.42, 1.0, 0.70)
const WHT := Color(1.0, 0.97, 1.0)
## The afterglow: the ribbons a few thirtieths of a second ago, fainter each.
const LAGS := [[1, 0.30], [2, 0.20], [3, 0.13], [5, 0.07]]
## The ghost of the curtains: the ribbons at these moments, kept in the sky after the snap.
const GHOST_TS := [4.7, 4.9, 5.1, 5.22]
## The film's own rolls (r9.py): a delay per band of rows (rng 9); each band's wave, twist and
## hue (rng 4); 160 sparks (rng 33); the corona's 54 rays and 90 motes (rng 5), x from the stern.
const ROW_RND := [0.8702, 0.2868, 0.6031, 0.7775, 0.7161, 0.9154, 0.8604, 0.9182, 0.0266, 0.4372, 0.4849, 0.0652, 0.0056, 0.8306, 0.9833, 0.7846, 0.3156, 0.7053, 0.2992, 0.7407, 0.2797, 0.7826, 0.9877, 0.9862]
const G_AMP := [25.0889, 18.1812, 25.6199, 11.2934, 19.7177, 16.0238, 22.8304, 12.7924, 23.9462, 18.7031, 24.4354, 17.6345, 16.8879, 22.6231, 25.7464, 15.9156, 25.5029, 24.8644, 12.8431, 19.7416, 21.2778, 25.0849, 20.6505, 12.1343]
const G_LAM := [117.3614, 117.0853, 117.5147, 147.3078, 107.7459, 99.5451, 118.9357, 126.6761, 146.0420, 122.8310, 102.4092, 145.4354, 116.9621, 128.9271, 115.9425, 99.1037, 130.0159, 135.0910, 97.4013, 114.8945, 108.5180, 96.0974, 99.3879, 147.5630]
const G_FRQ := [1.1863, 0.9103, 1.1067, 0.7231, 1.2033, 0.9954, 1.1511, 0.8518, 0.9069, 0.8914, 1.2348, 0.9362, 0.9748, 1.2258, 1.1968, 0.9173, 0.8690, 1.1439, 0.7591, 0.9157, 1.1820, 1.2047, 0.8284, 0.7433]
const G_PHI := [4.9494, 3.9067, 1.4923, 3.1786, 0.4487, 4.3988, 3.3095, 4.4274, 0.5540, 4.0515, 2.3269, 3.1372, 2.1079, 3.9841, 3.5705, 3.8774, 0.3982, 1.4146, 0.4518, 2.4083, 3.0223, 0.7059, 4.1946, 3.0622]
const G_TAU := [82.5181, 87.8606, 106.4183, 87.3876, 60.1415, 63.0558, 93.1641, 72.7439, 96.5408, 83.0851, 75.8829, 95.6697, 65.0639, 70.6647, 71.0567, 77.8425, 104.8913, 99.6897, 100.1882, 89.7132, 55.4518, 70.7373, 82.5990, 104.4150]
const G_TW := [2.7276, 3.1011, 3.6971, 2.6828, 3.4961, 3.1901, 3.0507, 3.2596, 2.9697, 2.2259, 3.7938, 3.9395, 3.6663, 2.7076, 3.2678, 3.5415, 2.1245, 3.5789, 2.1698, 3.8796, 2.4829, 3.9263, 2.4641, 3.0708]
const G_RISE := [0.1398, 0.1585, 0.1247, 0.1402, 0.0870, 0.1301, 0.0862, 0.1516, 0.1328, 0.0855, 0.1341, 0.0480, 0.1510, 0.1232, 0.0793, 0.1176, 0.1341, 0.1154, 0.1464, 0.0898, 0.0784, 0.0845, 0.0738, 0.0975]
const G_HUE := [0.0772, 0.1124, 0.0398, 0.0857, 0.1410, 0.0479, -0.1246, 0.0377, -0.1441, 0.0533, 0.1495, -0.0034, 0.1299, -0.1441, 0.1395, -0.0995, 0.1019, -0.0605, -0.0320, -0.1102, -0.1388, 0.0757, 0.0738, -0.1129]
const SP_T0 := [2.3349, 2.3471, 2.3489, 2.3517, 2.3604, 2.3611, 2.3628, 2.3661, 2.4147, 2.4280, 2.4315, 2.4512, 2.4957, 2.5194, 2.5277, 2.5326, 2.5664, 2.6444, 2.6872, 2.7043, 2.7265, 2.7438, 2.7889, 2.7918, 2.8012, 2.8526, 2.8549, 2.8708, 2.8733, 2.8873, 2.9005, 2.9011, 2.9164, 2.9171, 2.9243, 2.9392, 2.9556, 3.0383, 3.0385, 3.0550, 3.0659, 3.0660, 3.0755, 3.1123, 3.1169, 3.2021, 3.2052, 3.2132, 3.2143, 3.2159, 3.2166, 3.2876, 3.2917, 3.2930, 3.3206, 3.3325, 3.3455, 3.3953, 3.4064, 3.4574, 3.4664, 3.5028, 3.5046, 3.5222, 3.5235, 3.5297, 3.5308, 3.5731, 3.5964, 3.6175, 3.6364, 3.6455, 3.6493, 3.6531, 3.6531, 3.6782, 3.7015, 3.7165, 3.7416, 3.7918, 3.8068, 3.8097, 3.8691, 3.8741, 3.9037, 3.9048, 3.9349, 3.9400, 3.9421, 3.9563, 3.9784, 3.9811, 3.9818, 4.0339, 4.0414, 4.0516, 4.0585, 4.0598, 4.0958, 4.1181, 4.1516, 4.2019, 4.2200, 4.2381, 4.2640, 4.2843, 4.2854, 4.2889, 4.2891, 4.2984, 4.3429, 4.3473, 4.3553, 4.3829, 4.4128, 4.4181, 4.4553, 4.4595, 4.4635, 4.4646, 4.4711, 4.4962, 4.5315, 4.5574, 4.5782, 4.5816, 4.6069, 4.6311, 4.6330, 4.6565, 4.6901, 4.6995, 4.7511, 4.7547, 4.7650, 4.7656, 4.7848, 4.8292, 4.8459, 4.8694, 4.8973, 4.8992, 4.9624, 4.9945, 5.0175, 5.0193, 5.0309, 5.0594, 5.0697, 5.0823, 5.1323, 5.1386, 5.1425, 5.1433, 5.1653, 5.1673, 5.1953, 5.2248, 5.2829, 5.3463]
const SP_VX := [22.7776, 42.7987, 22.9734, 42.1809, 44.8150, 32.4825, 88.3148, 21.5886, 36.2454, 65.7426, 55.1012, 61.6455, 21.4006, 44.8840, 55.9532, 25.4402, 42.2642, 57.0717, 51.9870, 57.5668, 31.1665, 59.4839, 78.1732, 35.1134, 53.2753, 41.7090, 33.8635, 86.0739, 48.2608, 20.7587, 37.3516, 29.5482, 31.8984, 50.1314, 46.8520, 64.3155, 71.1002, 38.9822, 33.3386, 39.7846, 45.8137, 38.2538, 39.1162, 85.1227, 26.4921, 76.1982, 51.8330, 60.2062, 76.8378, 51.5477, 79.8681, 39.0527, 66.0730, 23.7969, 50.3985, 34.1189, 74.5225, 76.9791, 80.4914, 56.8582, 48.4768, 51.7247, 65.6963, 79.6195, 41.9931, 88.1770, 53.4756, 61.6076, 21.7661, 35.6720, 62.4956, 73.9748, 41.5678, 59.5860, 33.0459, 26.9138, 64.2348, 59.5539, 62.6212, 27.5689, 48.5690, 62.6074, 83.6306, 33.0881, 78.2970, 75.4070, 24.4859, 68.9340, 84.6030, 60.5052, 50.5648, 68.0944, 50.6724, 58.1165, 69.9081, 42.1736, 35.2496, 44.3173, 32.7811, 79.7519, 49.6210, 22.7030, 70.3894, 81.5165, 73.9843, 70.4980, 42.6110, 35.9844, 66.4274, 50.7525, 23.1666, 24.5427, 54.8287, 61.7534, 50.1858, 83.1805, 21.7789, 52.7749, 32.0174, 71.4604, 32.7965, 38.9505, 60.3540, 74.8868, 25.2854, 45.4053, 66.8667, 41.1041, 26.2159, 59.7789, 53.0570, 29.5963, 58.7862, 56.2527, 44.2361, 60.8207, 86.7740, 21.9190, 75.2173, 86.4167, 83.3533, 34.1042, 29.1862, 79.7693, 60.2080, 67.1660, 52.0964, 56.6146, 62.9478, 59.0767, 79.6804, 61.8422, 31.3427, 88.6322, 30.8710, 78.2636, 28.6200, 47.4528, 23.6220, 72.2958]
const SP_VY := [-17.5713, -8.1399, 0.7142, -20.8146, -32.5209, -34.5896, -12.1977, -0.2462, -1.0670, -36.4204, -18.3655, -7.5603, 11.8373, 3.9811, -1.3666, -35.9333, 13.3077, -7.6677, -2.2610, -18.0730, -9.7666, -12.1939, -13.4164, -21.9161, 5.8169, 9.8830, -15.7634, -20.9823, -20.7955, -11.6081, 19.0658, -8.6265, 26.2288, -28.6627, -25.5747, -20.1485, -21.5072, -0.4297, 24.6793, -19.2390, -0.1026, 17.3953, 36.4877, -2.3755, 11.4123, 17.5006, -4.2618, 4.1244, -12.1729, -21.6311, -16.4122, 14.6159, 17.9491, -1.3806, -27.4747, 16.1065, -5.7407, 20.8862, -3.8715, -26.0911, -10.6650, -17.4459, 22.6171, -45.9105, -16.0680, -11.1256, -41.8127, 2.0239, 5.3919, 9.5491, 9.2722, -7.2399, 11.2058, -13.4208, -4.9598, -1.5895, -4.2019, 3.6040, -17.1453, -7.6870, -15.9437, -4.3007, 0.0222, -18.8529, 20.2030, 28.9793, 4.4693, -3.7037, -16.4472, -8.3703, -9.1646, 6.9824, -5.4009, 7.2328, 4.7947, -13.7768, -28.7518, -26.1200, -24.0808, -5.6556, 15.7783, -21.5465, 6.3964, -8.2243, 17.2708, 34.7629, 13.8223, 0.9891, 3.9967, 18.3269, -10.0367, -18.6337, -1.7860, 23.7343, -17.3006, 15.0087, 10.8009, -8.6950, -18.8086, -33.7893, -25.4318, -1.9560, 8.1387, -16.1648, -15.1860, -18.8063, 38.2342, -29.6220, -31.5168, 13.5807, -24.8713, 12.3863, -20.2609, 12.7818, 18.9982, -13.8123, -5.9985, -23.3077, 9.9618, -11.3300, -22.6552, 2.0483, 0.7660, -6.6826, -13.5614, 11.2361, -17.5959, -21.3288, -10.3598, 3.2967, -12.9400, -17.3114, -24.3563, -20.3688, -18.0524, 29.4012, -38.0865, -14.4158, -5.0674, -22.0534]
const SP_LIFE := [0.5602, 1.2272, 0.7001, 0.6736, 0.4008, 1.2178, 0.9576, 0.8238, 1.0127, 0.7084, 0.5616, 0.7621, 0.5544, 0.8001, 0.9034, 0.5819, 0.9091, 0.6636, 0.6167, 1.2719, 1.2635, 0.9129, 0.8004, 0.6201, 0.9380, 1.0320, 0.6949, 1.0217, 1.2222, 0.7886, 1.2937, 0.6029, 0.7765, 0.8217, 0.4186, 0.9200, 1.0986, 1.0687, 0.8990, 0.9247, 0.4843, 0.6482, 0.8833, 1.1076, 1.1706, 0.9525, 0.4512, 1.0997, 1.2851, 0.4494, 0.5885, 0.9436, 0.7716, 1.0496, 1.2432, 1.0538, 0.7867, 1.1658, 0.8092, 0.6434, 1.1478, 0.7536, 1.2419, 0.8036, 1.1819, 0.6960, 0.9282, 1.0458, 0.5404, 0.6223, 0.8061, 0.8272, 0.7864, 0.6828, 1.0641, 0.6981, 1.2457, 0.8297, 0.4681, 1.1107, 0.4754, 0.4418, 1.0735, 1.2427, 0.8044, 0.8365, 0.8366, 0.6788, 0.9982, 0.6626, 0.6672, 0.9991, 1.2972, 1.1961, 1.0569, 1.0322, 0.4681, 1.0284, 0.6608, 0.4800, 0.7523, 0.7173, 0.6245, 0.5370, 0.8825, 1.0670, 1.0220, 0.8467, 1.2399, 1.1889, 1.2597, 0.7700, 1.1452, 0.5572, 1.0875, 0.4349, 0.5262, 0.7177, 0.8229, 1.2873, 0.6010, 0.6793, 1.0985, 1.1546, 0.5651, 0.4139, 0.6386, 0.5291, 0.7131, 0.5633, 0.5418, 0.4713, 0.9307, 0.7339, 0.4662, 0.5786, 0.9137, 0.4428, 0.4187, 1.0621, 0.6020, 0.7183, 1.0769, 0.6859, 0.6522, 1.0564, 1.2753, 1.1926, 1.2717, 0.9057, 0.4879, 0.8812, 0.4525, 1.1208, 0.4671, 0.4271, 0.6371, 0.7352, 0.9639, 0.5650]
const SP_B := [1.3968, 0.6135, 1.3904, 0.9919, 0.9299, 0.8636, 0.8970, 0.6472, 1.0891, 0.6422, 0.7448, 0.6582, 0.7248, 0.9355, 1.3601, 1.1334, 0.6988, 1.3233, 0.8905, 0.8827, 1.2059, 1.2913, 0.8270, 0.7754, 0.8368, 0.7108, 0.9072, 0.8507, 0.8986, 0.6588, 1.2300, 1.2474, 0.8067, 1.2602, 1.3089, 1.1271, 1.2451, 1.3511, 0.8724, 0.6325, 1.1161, 0.9181, 0.9604, 1.1113, 1.3653, 1.1090, 1.1084, 0.8128, 0.9007, 0.8340, 1.1946, 1.3371, 0.6908, 1.1393, 1.2594, 1.1346, 1.2172, 1.2942, 0.6261, 1.2180, 1.2977, 1.3164, 0.6023, 0.9761, 1.0894, 0.6128, 1.3112, 0.6447, 0.6761, 0.9782, 0.6068, 1.1505, 1.3942, 0.9823, 1.0321, 0.9232, 1.2870, 0.6342, 1.0946, 1.2513, 1.3914, 0.9452, 0.8613, 1.3235, 0.8515, 0.9554, 1.3143, 0.9122, 0.7390, 0.8728, 0.8649, 0.7218, 0.8061, 1.1068, 1.3691, 0.6005, 0.9116, 1.2587, 0.7065, 0.8308, 0.9661, 0.6594, 0.7481, 1.1721, 1.0387, 0.6685, 0.6602, 0.6334, 0.6765, 0.7869, 0.8092, 1.0880, 0.7276, 0.7595, 0.7321, 1.0198, 1.1315, 0.6359, 0.7809, 1.3627, 1.1860, 1.0291, 1.1762, 0.6395, 0.6198, 0.8893, 0.9718, 1.3500, 0.6391, 1.2075, 1.0404, 1.1367, 0.8538, 1.2649, 1.2649, 0.8940, 1.0660, 0.7995, 0.6377, 0.8738, 0.6126, 0.8067, 1.3258, 0.7862, 1.2021, 0.8492, 1.2721, 1.3627, 0.6653, 1.2705, 1.2681, 0.7956, 0.7195, 1.3832, 0.9091, 1.0783, 0.8858, 0.6205, 1.2849, 1.0574]
const SP_ROW := [21, 17, 3, 75, 60, 11, 1, 57, 62, 46, 19, 27, 58, 77, 62, 62, 86, 77, 24, 29, 57, 69, 42, 48, 58, 67, 6, 71, 22, 33, 10, 56, 53, 79, 3, 9, 59, 84, 70, 26, 87, 70, 78, 17, 76, 91, 83, 51, 83, 4, 2, 37, 62, 59, 23, 63, 41, 31, 39, 88, 33, 38, 23, 17, 59, 75, 57, 86, 10, 67, 47, 21, 10, 28, 20, 69, 61, 3, 0, 26, 65, 46, 19, 14, 90, 79, 60, 75, 67, 68, 44, 30, 84, 80, 25, 72, 40, 46, 26, 18, 12, 5, 4, 53, 57, 6, 73, 53, 54, 1, 44, 71, 30, 81, 60, 78, 37, 78, 88, 63, 37, 76, 17, 20, 88, 67, 1, 66, 61, 50, 12, 43, 53, 65, 75, 0, 40, 17, 47, 32, 30, 83, 22, 47, 35, 33, 41, 31, 28, 33, 88, 86, 34, 4, 34, 37, 29, 80, 77, 81]
const CR_ANG := [5.0580, 5.0764, 3.2379, 1.7957, 0.3389, 2.4088, 2.5665, 0.2845, 0.3064, 6.2780, 4.0990, 1.4735, 2.7329, 6.1210, 5.6403, 5.3045, 2.4656, 3.0978, 4.2518, 0.3820, 3.4909, 1.7056, 5.5270, 0.4035, 4.2674, 5.4669, 1.4283, 5.6263, 5.4802, 0.1163, 4.4453, 0.0075, 3.1627, 2.7437, 1.2771, 2.0417, 5.0656, 1.9883, 0.9364, 4.3889, 2.8183, 5.0199, 1.4798, 2.0093, 5.0258, 3.1860, 3.1817, 1.4841, 0.0913, 5.8636, 0.5393, 5.3088, 2.3115, 5.9755]
const CR_LEN := [139.8851, 247.2884, 171.2320, 108.0271, 208.2843, 194.8779, 196.8410, 152.7649, 104.3777, 188.1880, 81.4179, 198.4445, 187.0774, 135.3025, 219.7047, 98.8051, 138.0918, 219.5868, 136.0951, 202.6516, 182.5036, 248.2002, 258.3353, 204.7353, 221.7688, 90.5730, 202.5781, 229.5249, 140.2451, 170.6500, 155.8976, 251.7046, 123.4556, 140.4169, 60.1840, 144.0369, 186.2872, 246.9922, 244.7353, 125.4700, 257.7722, 97.5350, 224.6504, 91.4519, 141.0197, 74.6947, 231.6078, 225.7596, 87.9579, 165.4213, 111.6283, 158.3551, 170.6412, 81.2524]
const CR_B := [1.0915, 0.6230, 0.7577, 0.4458, 0.4022, 0.5561, 0.6733, 1.1425, 1.1118, 0.7844, 0.7638, 0.9336, 1.0870, 0.6698, 1.0349, 0.7192, 0.8752, 0.9900, 0.8011, 0.9526, 0.9579, 0.4046, 0.4313, 0.5192, 0.5709, 0.5626, 0.4392, 0.5738, 0.8808, 1.1089, 0.6796, 0.6931, 0.7334, 0.9443, 1.0282, 1.1528, 0.7006, 0.9654, 0.6733, 1.0592, 0.5845, 1.0968, 0.8041, 0.9803, 0.8280, 0.6529, 0.7954, 0.4404, 0.4344, 0.8240, 0.7817, 1.0665, 0.4161, 0.8455]
const MO_X0 := [411.02, 468.13, 538.14, 429.16, 449.54, 411.63, 477.29, 282.00, 443.99, 507.71, 251.67, 676.88, 547.12, 658.24, 306.38, 385.94, 289.09, 174.84, 158.87, 281.27, 608.19, 237.09, 516.88, 282.67, 184.89, 252.40, 510.66, 416.88, 442.08, 391.08, 295.95, 409.80, 640.74, 257.20, 539.81, 283.60, 252.90, 322.29, 199.36, 647.62, 344.25, 243.55, 150.00, 182.15, 264.19, 372.19, 470.04, 671.91, 623.73, 278.88, 475.34, 640.26, 204.05, 604.35, 360.71, 565.86, 321.62, 482.88, 419.73, 205.55, 554.21, 587.81, 406.95, 356.42, 654.07, 349.13, 617.96, 372.68, 348.71, 342.28, 181.92, 297.53, 272.08, 183.17, 438.11, 385.25, 163.36, 232.95, 638.75, 221.08, 348.61, 655.81, 210.31, 368.03, 576.19, 160.15, 186.08, 644.72, 514.01, 288.87]
const MO_Y0 := [-33.50, -52.06, -7.12, -18.83, -19.11, -18.57, -2.62, -2.34, 15.02, 14.14, 24.63, 10.97, -18.73, -11.41, 2.85, -18.07, 4.29, 19.99, -30.83, -56.03, 21.04, -9.54, 8.43, -44.64, 35.06, 9.20, -13.28, -19.15, -7.04, -14.34, -17.25, -39.11, 22.83, -11.03, -8.06, -7.58, -71.31, 3.71, -18.56, -17.52, -8.19, -35.28, 11.93, -28.09, -33.50, -32.42, -5.87, 9.39, -25.47, -49.26, 17.62, -37.69, 21.07, -11.41, -28.16, -26.64, 2.01, 13.12, -15.15, 14.62, 44.26, -15.42, -39.89, -37.41, -46.15, -26.63, -28.82, -44.45, 3.78, -77.89, -44.34, 42.40, 16.98, 3.59, 1.89, 36.04, 3.93, -7.98, -41.98, -11.92, -29.08, -28.36, -28.57, -11.16, -18.57, 12.65, -44.48, -14.41, 38.35, -8.99]
const MO_VX := [26.7806, 25.9161, 28.4331, 20.3337, -9.3262, 6.2566, 4.6753, -11.6840, 3.5057, -7.5011, -13.3177, 12.9525, 9.3897, 0.3706, -3.3082, 2.4222, 4.4827, 4.2865, 9.2621, 3.9024, 15.4176, 17.3202, 15.0102, 0.7166, 1.3689, 16.0881, 7.2414, 9.3959, -24.8879, -27.8015, 14.7201, 14.6138, 29.5080, 20.0963, 13.1043, 10.2291, -9.9744, 22.3645, 1.5498, 17.0348, 12.8006, 13.8094, 22.4975, 3.1419, 4.5787, -1.9821, 4.7199, 33.3232, 4.9135, 26.5986, 21.5642, 20.2099, 21.2422, -4.1999, 15.2283, 32.2378, 0.2589, 9.3405, 0.3518, 14.4382, -5.0994, 32.5355, 4.7243, -11.5973, 35.0711, 23.5873, 17.2592, 17.4562, 4.9908, 6.8739, 20.1363, 22.8467, 23.0566, 12.9757, 3.4706, 7.3108, 25.5344, 30.1589, 5.2216, 3.3177, 27.4657, 20.1311, 19.7616, -8.3727, 4.7674, 2.7901, 12.9107, -13.5892, 27.8045, 14.2018]
const MO_VY := [-4.5213, -17.4731, -8.2114, 2.6772, -20.5576, -5.5539, -2.4096, -13.5356, -1.4821, -10.6406, 1.8381, -3.7799, -6.2051, 8.0713, -1.3448, 2.4691, -17.5162, -13.1729, -1.3074, -0.7551, -8.4459, -1.7622, -16.4668, -6.2893, -17.1783, -5.2754, -11.8894, -13.1280, -7.5496, 6.5397, -16.0941, -12.8140, 0.5413, -11.3885, 6.1541, -6.2198, -7.2749, -5.1449, 5.9294, -2.7571, -3.8663, -5.9851, -20.4994, -15.0822, 3.8668, -1.4250, -3.9515, -2.9035, -12.3487, -5.2963, -15.2064, -4.8691, -13.7131, -9.7106, -4.3727, -10.6143, -2.8193, -4.3517, -5.1243, 2.5953, -19.7911, -20.7703, -3.0701, -0.4736, 8.0931, -1.9499, -1.3583, -15.0646, -1.9790, -2.6093, -16.4469, -15.1705, -8.8882, -5.6940, -31.5583, -7.4376, -6.1532, -9.4147, -5.8654, -4.3528, -16.0931, -4.6706, -10.0105, -15.5670, -6.3269, 3.9012, -19.6809, -21.2249, -21.2253, 7.8185]
const MO_LIFE := [2.5999, 1.2718, 2.3123, 1.7639, 1.8918, 2.2189, 1.0306, 1.8813, 1.8265, 1.7721, 1.0021, 1.0203, 1.8818, 1.8202, 1.6025, 1.2094, 1.6550, 2.2112, 2.4753, 2.3759, 1.0031, 1.6095, 1.8806, 2.4657, 2.0163, 2.4434, 2.2406, 1.1304, 2.7659, 2.0036, 2.0866, 1.4664, 2.6255, 2.7970, 1.6172, 1.8804, 1.1139, 2.3739, 2.1581, 1.4204, 2.4937, 1.9849, 2.6721, 2.4764, 1.1810, 1.4272, 2.5271, 1.0568, 1.2347, 2.6550, 2.4591, 1.4590, 1.6096, 1.0686, 1.2282, 1.0202, 2.0567, 2.0990, 1.2590, 2.5001, 1.8775, 2.0789, 2.1924, 1.3695, 2.4466, 1.7395, 1.8965, 1.2270, 1.4588, 1.8196, 2.3038, 1.8236, 2.0087, 2.3625, 1.7248, 1.0285, 2.0107, 2.6993, 1.0682, 1.8330, 2.1780, 1.8803, 1.1863, 1.9248, 1.1436, 1.1265, 1.6086, 1.3192, 1.9078, 2.7002]
const MO_B := [0.6505, 1.1921, 0.7445, 1.0849, 0.8659, 1.0464, 1.1057, 1.0893, 0.6033, 1.1239, 0.5839, 1.0141, 0.5320, 0.7101, 0.5923, 0.9351, 0.7204, 0.8964, 0.6529, 0.7794, 1.1310, 0.9182, 0.8407, 1.0081, 1.1948, 0.7337, 0.5768, 0.6686, 0.6095, 0.7837, 1.0195, 1.0364, 0.5756, 0.6135, 0.7521, 1.0910, 0.8387, 0.8774, 0.7038, 0.8849, 0.9236, 0.7354, 0.9211, 1.0279, 0.7478, 0.8192, 0.5912, 0.6816, 0.5285, 0.5394, 0.5590, 1.1283, 1.0126, 0.9098, 1.0588, 0.6232, 0.7463, 0.9073, 1.0986, 0.8783, 0.5879, 0.5310, 0.5245, 1.0293, 1.1261, 0.6017, 1.0670, 0.5293, 1.0846, 0.9916, 0.8314, 0.8340, 0.6536, 1.1515, 0.6905, 0.6853, 1.0399, 0.9038, 0.8617, 0.8996, 0.5773, 0.5764, 1.1852, 0.9920, 0.9303, 0.8925, 0.6643, 0.6097, 0.9089, 0.5071]

var vp := Vector2.ZERO
var mid_y := 0.0
var rows := 0
var row_l := PackedFloat32Array()
var row_r := PackedFloat32Array()
var row_delay := PackedFloat32Array()
var pe := PackedFloat32Array()
var tk := PackedFloat32Array()
var sp_f := PackedFloat32Array()
var fibres: Array[Vector4] = []
var fib_b: Array[Vector3] = []
var _bufs: Array[SubViewport] = []
var _all: Array[ShaderMaterial] = []
var _now: Array[ShaderMaterial] = []
var _lag_mats: Array[ShaderMaterial] = []
var _specks: R9Specks
var _ghost: SubViewport
var _ready := false
var _low := false


func _init() -> void:
	id = &"r9"
	length = 10.0
	hit_t = T_SNAP
	cut_t = 5.8
	commit_t = 9.0
	swap_t = 0.6
	flash_floor = 0.30


func setup(_stage: JumpStage, _place: JumpPlace, _hull: JumpHull) -> void:
	super(_stage, _place, _hull)
	stage.build(SHADER, place.window)
	_low = DisplaySettings.graphics_low
	var ih := place.ink.size.y
	mid_y = place.ink.position.y + roundf(50.0 / FILM_H * ih)
	vp = Vector2(place.ink.end.x + roundf(place.ahead(VP_AHEAD)), mid_y - 22.0)
	stage.set1(&"vp", vp)
	stage.set1(&"core", place.core)
	stage.set1(&"ink", Vector4(place.ink.position.x, place.ink.position.y, place.ink.size.x, place.ink.size.y))
	stage.set1(&"ship", Vector4(place.canvas.position.x, place.canvas.position.y, place.canvas.size.x, place.canvas.size.y))
	stage.set2(&"centre", vp)
	stage.set2(&"bloom", 0.0 if _low else 1.08)
	stage.set2(&"flash_r", 200.0)
	stage.set2(&"flash_col", Vector3(0.779, 0.856, 0.925))
	# the plates: the film's columns, fitted to this hull's length; each goes quicker than the last
	pe.resize(9)
	tk.resize(9)
	for k in 9:
		pe[k] = float(PE[k]) * place.ink.size.x / FILM_W
		tk[k] = T_UNR + (T_DONE - T_UNR) * pow(float(k) / 8.0, 0.78)
	stage.set1(&"pe", pe)


	_build()


## The hull is baked: its rows become threads (in the opening, long before the first plate
## goes at 2.3 s); every draw learns them.
func hull_ready() -> void:
	super()
	_rows_from(hull)
	var wr := Vector4(place.window.position.x, place.window.position.y, place.window.size.x, place.window.size.y)
	for m in _all:
		_tables(m, wr)
	# the ghost's four moments are drawn once, now the rows are known
	_ghost.render_target_update_mode = SubViewport.UPDATE_ONCE
	_ready = true


## The light buffers and the draws into them, built with the stage so the world pass never
## reads a buffer that is not there yet; they draw nothing until the hull's rows are known.
func _build() -> void:
	rows = mini(int(place.ink.size.y), 160)
	var line_n := rows * _maxj(1)
	var curt_n := rows * _maxj(3)
	# A: the back band's lines and the corona's burst; B: the front band's lines and the specks
	var a := _buf(1.0, &"l_back")
	_now.append(_draw(a, THREADS, line_n, 1, {mode = 0, band = 0, gain = K_LINE}))
	_now.append(_draw(a, THREADS, 54 * 200, 1, {mode = 3, gain = K_LINE, maxj = 200}))
	var b := _buf(1.0, &"l_front")
	_now.append(_draw(b, THREADS, line_n, 1, {mode = 0, band = 1, gain = K_LINE}))
	_specks = R9Specks.new()
	_specks.k = K_LINE
	b.add_child(_specks)
	# C: the curtains; D: the afterglow (the ribbons as they were a few frames back)
	_now.append(_draw(_buf(1.0, &"l_curt"), THREADS, curt_n, 3, {mode = 1, gain = 0.5 * K_CURT}))
	if not _low:
		var d := _buf(1.0, &"l_lag")
		for _lg: Array in LAGS:
			_lag_mats.append(_draw(d, THREADS, line_n, 1, {mode = 0, band = 2}))
			_lag_mats.append(_draw(d, THREADS, curt_n, 3, {mode = 1}))
	# E: the paint near the roots; F: the ribbons' brightness at a quarter size, to light the sky
	var e := _buf(1.0, &"l_matter")
	_now.append(_draw(e, MATTER, line_n, 1, {mode = 2, band = 0}))
	_now.append(_draw(e, MATTER, line_n, 1, {mode = 2, band = 1}))
	var f := _buf(4.0, &"l_lum")
	_now.append(_draw(f, THREADS, line_n, 1, {mode = 0, band = 2, as_lum = 1, gain = 1.0 / 16.0}))
	_now.append(_draw(f, THREADS, curt_n, 3, {mode = 1, as_lum = 1, gain = 2.0 / 16.0}))
	# G: the ghost of the curtains, drawn once from four fixed moments
	var gv := _buf(1.0, &"l_ghost")
	gv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_ghost = gv
	for gt: float in GHOST_TS:
		_draw(gv, THREADS, line_n, 1, {mode = 0, band = 2, t = gt, gain = 0.5 * K_GHOST, taut = _taut(gt), reel = _reel(gt)})
		_draw(gv, THREADS, curt_n, 3, {mode = 1, t = gt, gain = 1.4 * K_GHOST, taut = _taut(gt), reel = _reel(gt)})
	stage.set1(&"lag_on", 0.0 if _low else 1.0)


## Slots a row takes: a row's thread is at most the hull's length pulled out, one slot a step.
func _maxj(stride: int) -> int:
	return int(ceil(ceil(place.ink.size.x * STR / STEP + 1.0) / float(stride)))


## A light buffer the size of the window (or `cell` times smaller), drawn in screen coordinates.
func _buf(cell: float, pname: StringName) -> SubViewport:
	var v := SubViewport.new()
	v.size = Vector2i((place.window.size / cell).ceil())
	v.transparent_bg = true
	v.disable_3d = true
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	v.set_meta(&"cell", cell)
	stage.add_child(v)
	v.canvas_transform = Transform2D(0.0, Vector2(1.0 / cell, 1.0 / cell), 0.0, -place.window.position / cell)
	stage.set1(pname, v.get_texture())
	_bufs.append(v)
	return v


func _draw(v: SubViewport, sh: Shader, n: int, stride: int, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"stride", stride)
	m.set_shader_parameter(&"maxj", _maxj(stride))
	m.set_shader_parameter(&"cell", float(v.get_meta(&"cell", 1.0)))
	for key in params:
		m.set_shader_parameter(StringName(key), params[key])
	var node := ChartSky.MeshDraw.new()
	node.mesh = MapChart.empty_quads(n)
	node.material = m
	v.add_child(node)
	_all.append(m)
	return m


## What every draw of the threads shares: the hull, its rows, the bands, the plates.
func _tables(m: ShaderMaterial, wr: Vector4) -> void:
	m.set_shader_parameter(&"hull", hull.tex)
	m.set_shader_parameter(&"hull_size", Vector2(hull.size))
	m.set_shader_parameter(&"ink_c", Vector2(hull.ink.position))
	m.set_shader_parameter(&"ink_s", place.ink.position)
	m.set_shader_parameter(&"origin", Vector2(wr.x, wr.y))
	m.set_shader_parameter(&"rows", rows)
	m.set_shader_parameter(&"pe", pe)
	m.set_shader_parameter(&"tk", tk)
	m.set_shader_parameter(&"vp", vp)
	var rd := PackedVector4Array()
	var ih := float(rows)
	for r in rows:
		var g := (r / 4) % G_AMP.size()
		var gy := float(mini(r / 4 * 4 + 3, rows - 1) + r / 4 * 4) * 0.5
		var spr := clampf((gy - 50.0 / FILM_H * ih) / (46.0 / FILM_H * ih), -1.0, 1.0)
		rd.append(Vector4(row_l[r], row_r[r], row_delay[r], spr))
	m.set_shader_parameter(&"row_d", rd)
	var ga := PackedVector4Array()
	var gb := PackedVector4Array()
	for g in G_AMP.size():
		ga.append(Vector4(G_AMP[g], G_LAM[g], G_FRQ[g], G_PHI[g]))
		gb.append(Vector4(G_TAU[g], G_TW[g], G_RISE[g], G_HUE[g]))
	m.set_shader_parameter(&"g_a", ga)
	m.set_shader_parameter(&"g_b", gb)
	m.set_shader_parameter(&"ng", G_AMP.size())
	var cr := PackedVector3Array()
	for i in CR_ANG.size():
		cr.append(Vector3(CR_ANG[i], CR_LEN[i], CR_B[i]))
	m.set_shader_parameter(&"cr", cr)


## The hull's ink rows: where each starts and ends, its delay; the fibres off the stern and the
## sparks' fronts.
func _rows_from(h: JumpHull) -> void:
	var img := h.image
	var ink := h.ink
	rows = mini(ink.size.y, 160)
	row_l.resize(rows)
	row_r.resize(rows)
	row_delay.resize(rows)
	var mid := 50.0 / FILM_H * float(rows)
	for r in rows:
		var lo := -1
		var hi := -1
		for x in ink.size.x:
			if img.get_pixel(ink.position.x + x, ink.position.y + r).a > 0.0:
				if lo < 0:
					lo = x
				hi = x
		row_l[r] = float(lo) if lo >= 0 else float(ink.size.x)
		row_r[r] = float(hi)
		row_delay[r] = 0.12 * float(ROW_RND[(r / 4) % ROW_RND.size()]) + 0.10 * absf(float(r) - mid) / mid
	var rs := float(rows) / FILM_H
	sp_f.resize(SP_T0.size())
	for i in SP_T0.size():
		var r := mini(int(float(SP_ROW[i]) * rs), rows - 1)
		sp_f[i] = front_of(r, float(SP_T0[i]))
	_fibres(h)


## Eighteen loose fibres lift off the stern's outline in the wake (the film's own pick, rng 21:
## edge pixels in the stern's first 70 columns, above row 40 or below row 62).
func _fibres(h: JumpHull) -> void:
	var w := h.ink.size.x
	var hh := h.ink.size.y
	var a := PackedByteArray()
	a.resize(w * hh)
	for y in hh:
		for x in w:
			a[y * w + x] = 1 if h.image.get_pixel(h.ink.position.x + x, h.ink.position.y + y).a > 0.0 else 0
	var er := JumpHull.erode_mask(JumpHull.erode_mask(a, w, hh), w, hh)
	var ys := float(hh) / FILM_H
	var cand: Array[Vector2] = []
	for y in hh:
		for x in mini(w, int(70.0 * float(w) / FILM_W)):
			var i := y * w + x
			if a[i] == 1 and er[i] == 0 and (float(y) < 40.0 * ys or float(y) > 62.0 * ys):
				cand.append(Vector2(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in mini(18, cand.size()):
		var c: Vector2 = cand[rng.randi() % cand.size()]
		fibres.append(Vector4(c.x, c.y, rng.randf_range(1.25, 2.2), rng.randf_range(10.0, 30.0)))
		fib_b.append(Vector3(-1.0 if c.y < 46.0 * ys else 1.0, rng.randf_range(0.0, 6.28), 0.0))


## The unravel front of row r at t, in ink columns (as the threads' shader works it out).
func front_of(r: int, t: float) -> float:
	var tt := t - row_delay[r]
	var F := -1.0
	for k in 8:
		if tt >= tk[k]:
			F = pe[k] + (pe[k + 1] - pe[k]) * ease5((tt - tk[k]) / (0.78 * (tk[k + 1] - tk[k])))
	return F


static func _reel(t: float) -> float:
	if t < T_TAUT:
		return 0.0
	if t < T_HOLD:
		return 0.30 * pow(ease3((t - T_TAUT) / (T_HOLD - T_TAUT)), 1.4)
	if t < T_ZIP:
		return 0.30 + 0.04 * ease3((t - T_HOLD) / (T_ZIP - T_HOLD))
	return minf(1.0, 0.34 + 0.66 * pow((t - T_ZIP) / (T_SNAP - T_ZIP), 1.5))


static func _taut(t: float) -> float:
	return ease3((t - T_TAUT + 0.15) / 0.6)


## The hull trembles a pixel as the plates go (16 a second, as the film's `hull_offset`).
static func hull_offset(t: float) -> Vector2:
	if t > T_UNR - 0.4 and t < T_TAUT:
		var s := ease3((t - (T_UNR - 0.4)) / 1.5)
		var fr := int(floor(t * 16.0))
		var d := Vector2.ZERO
		if held_rand(fr, 91) < 0.45 * s:
			d.y = float(int(held_rand(fr, 92) * 3.0) - 1)
		if held_rand(fr, 93) < 0.2 * s:
			d.x = float(int(held_rand(fr, 94) * 3.0) - 1)
		return d
	return Vector2.ZERO


func step(t: float) -> void:
	var hoff := hull_offset(t)
	var kt := _taut(t)
	var rl := _reel(t)
	var k_s := t - T_SNAP
	stage.set1(&"t", t)
	stage.set1(&"hoff", hoff)
	stage.set1(&"kt", kt)
	stage.set1(&"reel", rl)
	stage.set1(&"k_s", k_s)
	if _ready:
		_step_threads(t, hoff, kt, rl, k_s)
		_step_hull(t, hoff)
	_step_light(t, kt, k_s)
	# the snap: three frames of flash, the fringe, a 5 px shake
	var fl := 0.0
	if k_s >= 0.0:
		fl = [0.35, 0.9, 0.3, 0.12][int(k_s * 60.0)] if k_s < 4.0 / 60.0 else 0.12 * exp(-(k_s - 4.0 / 60.0) / 0.10)
	set_flash(fl, vp, 1.3)
	stage.set2(&"fringe", 5.0 * exp(-k_s / 0.12) if (k_s >= 0.0 and k_s < 0.6) else 0.0)
	var sh := Vector2.ZERO
	if k_s >= 0.0 and k_s < 0.55:
		sh = Vector2(smooth_noise(t, 0, 16.0), smooth_noise(t, 1, 16.0) * 0.8) * 5.0 * exp(-k_s / 0.15)
	set_shake(sh)


## Every draw of the threads gets this instant: the ribbons now, and the afterglow's past ones.
func _step_threads(t: float, hoff: Vector2, kt: float, rl: float, k_s: float) -> void:
	var on := t >= T_UNR - 0.05 and t < T_SNAP
	for m in _now:
		m.set_shader_parameter(&"t", t)
		m.set_shader_parameter(&"hoff", hoff)
		m.set_shader_parameter(&"taut", kt)
		m.set_shader_parameter(&"reel", rl)
		m.set_shader_parameter(&"k_s", k_s)
	# the afterglow: the ribbons at 30 fps a few frames back, as the film cached them
	var i0 := int(floor(t * 30.0))
	for li in LAGS.size():
		var tl := float(i0 - int(LAGS[li][0])) / 30.0
		var w: float = float(LAGS[li][1]) * 0.6 * K_LAG if (on and t > T_UNR and tl > T_UNR) else 0.0
		for j in 2:
			var m := _lag_mats[li * 2 + j]
			m.set_shader_parameter(&"t", tl)
			m.set_shader_parameter(&"gain", w * (0.8 if j == 0 else 1.0))
			m.set_shader_parameter(&"taut", _taut(tl))
			m.set_shader_parameter(&"reel", _reel(tl))
	if _specks != null:
		_specks.place(self, t, hoff, k_s)


## The hull that is left: each row's front, the plates' warning glow, the drive's pulses.
func _step_hull(t: float, hoff: Vector2) -> void:
	var fr := PackedVector2Array()
	fr.resize(160)
	var mid_r := -1
	var live: Array[int] = []
	for r in rows:
		var F := front_of(r, t)
		fr[r] = Vector2(F, row_r[r])
		if row_r[r] >= 0.0 and F >= 0.0 and F <= row_r[r]:
			live.append(r)
	if not live.is_empty():
		mid_r = live[live.size() / 2]
	stage.set1(&"fr", fr)
	stage.set1(&"rows", rows)
	var fs := Vector3.ZERO
	if mid_r >= 0 and t < T_TAUT:
		fs = Vector3(place.ink.position.x + hoff.x + fr[mid_r].x, place.ink.position.y + hoff.y + float(mid_r), 1.0)
	stage.set1(&"front_sp", fs)
	var pw := PackedFloat32Array()
	pw.resize(8)
	for k in 8:
		pw[k] = ease3((t - (tk[k] - 0.32)) / 0.32) * (1.0 if t < tk[k] + 0.25 else 0.0)
	stage.set1(&"pw", pw)


## The drive's light, the corona, the ghost of the curtains, the burst after the snap.
func _step_light(t: float, kt: float, k_s: float) -> void:
	# the drive: pulses that speed up, light crawling the seams from the core
	var pl := PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])
	var wake := Vector4.ZERO
	if t >= T_WAKE and t < T_TAUT:
		var tw := t - T_WAKE
		var s := ease3(tw / (T_UNR - T_WAKE))
		var a2 := 2.6 / (T_UNR - T_WAKE)
		var last := floorf(tw + a2 * tw * tw)
		for j in 4:
			var pk := last - float(j)
			if pk < 0.0:
				break
			var tp := (-1.0 + sqrt(1.0 + 4.0 * a2 * pk)) / (2.0 * a2)
			var dtp := tw - tp
			var amp := (0.2 + 0.6 * s) * exp(-dtp / 0.25)
			pl[j] = Vector4(dtp * (150.0 + 150.0 * s), amp, 5.0 + 6.0 * s, amp * 1.4 * exp(-dtp / 0.08))
		wake = Vector4(1.0, s, 6.0 + 16.0 * s, (0.1 + 0.5 * s) * (1.0 if t < T_UNR + 0.4 else 0.0))
	stage.set1(&"pl", pl)
	stage.set1(&"wake", wake)
	# the corona ahead, gathering
	var cor := Vector4.ZERO
	if t > 4.4 and t < T_SNAP:
		var g := ease3((t - 4.4) / (T_HOLD - 4.4))
		var tight := ease3((t - T_HOLD) / (T_SNAP - T_HOLD))
		var flick := 1.0 + 0.15 * (float(int(floor(t * 12.0)) % 2) - 0.5)
		cor = Vector4(g, tight, flick, 1.0)
	stage.set1(&"cor", cor)
	# the ghost of where the ribbons flowed: faint while taut, flared by the snap, drifting up, dissolving
	var ghost := Vector4.ZERO
	if t > T_TAUT - 0.1:
		var kk := maxf(k_s, 0.0)
		var left := ease3((t - (T_TAUT - 0.1)) / 0.7)
		var fade := left * (0.38 if k_s < 0.0 else (0.45 + 0.9 * exp(-kk / 0.35)) * exp(-kk / 1.3))
		ghost = Vector4(fade if fade > 0.01 else 0.0, 4.0 * kk, -12.0 * kk, ease3((kk - 0.15) / 2.5))
	stage.set1(&"ghost", ghost)
	stage.set1(&"rib_on", 1.0 if (t >= T_UNR - 0.05 and t < T_SNAP) else 0.0)
	stage.set1(&"hull_live", 1.0 if t < T_TAUT else 0.0)


func teardown() -> void:
	for v in _bufs:
		if is_instance_valid(v):
			v.queue_free()
	_bufs.clear()


## The fibres in the wake, the sparks off the front and the motes after the snap: a few hundred
## whole-pixel specks a frame, summed as light into the front band's buffer.
## Why: docs/why/SeqUnravel.md#specks
class R9Specks extends Node2D:
	var k := 0.25
	var _pts := PackedVector2Array()
	var _cols := PackedColorArray()

	func _init() -> void:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m

	func place(s: SeqUnravel, t: float, hoff: Vector2, k_s: float) -> void:
		_pts.clear()
		_cols.clear()
		var o := s.place.ink.position
		var fc := (MINT * 0.6 + WHT * 0.4)
		for i in s.fibres.size():
			var f := s.fibres[i]
			var u := (t - f.z) / 0.7
			if u <= 0.0 or t > T_UNR + 0.6:
				continue
			var L := f.w * JumpSequence.ease3(u)
			var dir := s.fib_b[i].x
			var phi := s.fib_b[i].y
			var ss := 0.0
			while ss < L:
				var bx := o.x + f.x + hoff.x - ss * 0.9
				var by := o.y + f.y + hoff.y + dir * ss * 0.45 + 2.5 * (ss / 20.0) * sin(ss * 0.35 - t * 9.0 + phi)
				var fade := (1.0 - ss / maxf(L, 1.0)) * 1.5 * (1.0 - JumpSequence.ease3((t - T_UNR) / 0.6))
				_add(bx, by, fc * fade)
				ss += 0.5
		if t > T_UNR and t < T_DONE + 1.8:
			var sc := (WHT * 0.6 + MINT * 0.4)
			var held := int(floor(t * 10.0))
			var rs := float(s.rows) / FILM_H
			for i in SP_T0.size():
				var age := t - float(SP_T0[i])
				if age <= 0.0 or age >= float(SP_LIFE[i]) or (held + i) % 4 == 0:
					continue
				var e := (1.0 - exp(-age / 0.5)) * 0.5
				var px := o.x + s.sp_f[i] + float(SP_VX[i]) * e + 40.0 * age
				var py := o.y + float(mini(int(float(SP_ROW[i]) * rs), s.rows - 1)) + float(SP_VY[i]) * e
				_add(px, py, sc * (float(SP_B[i]) * pow(1.0 - age / float(SP_LIFE[i]), 0.7) * 1.6))
		if k_s >= 0.0:
			var mc := (MINT * 0.7 + WHT * 0.3)
			var held := int(floor(k_s * 10.0))
			var dr := 1.0 - exp(-k_s / 0.8)
			var xs := (s.vp.x - o.x) / (772.0 - 90.0)
			for i in MO_X0.size():
				var life := 1.0 - k_s / float(MO_LIFE[i])
				if life <= 0.0 or (held + i) % 4 == 0:
					continue
				var px := o.x + float(MO_X0[i]) * xs + float(MO_VX[i]) * dr * 1.5
				var py := s.mid_y + float(MO_Y0[i]) + float(MO_VY[i]) * dr * 1.5 - 5.0 * k_s
				_add(px, py, mc * (float(MO_B[i]) * pow(life, 0.8) * 1.3))
		queue_redraw()

	func _add(x: float, y: float, c: Color) -> void:
		_pts.append(Vector2(floorf(x + 0.5), floorf(y + 0.5)))
		_cols.append(Color(c.r * k, c.g * k, c.b * k, 1.0))

	func _draw() -> void:
		for i in _pts.size():
			draw_rect(Rect2(_pts[i], Vector2.ONE), _cols[i], true)
