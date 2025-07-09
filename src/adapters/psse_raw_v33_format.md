
# 📘 PSS®E `.raw` File Format (Version 33) – Summary

The `.raw` file is a plain-text input format used by Siemens PSS®E for steady-state power system modeling. Version 33 supports a structured sequence of data sections, all representing a **positive-sequence balanced system**.

---

## 📌 Header Line

```
I, BASEMVA, REV, XFRRAT, NXFRAT, FREQ
```

| Field      | Description                            |
|------------|----------------------------------------|
| `I`        | Indicator: 0 = full data export        |
| `BASEMVA`  | System base MVA                        |
| `REV`      | RAW file version (33 in this case)     |
| `XFRRAT`   | Reserved                               |
| `NXFRAT`   | Reserved                               |
| `FREQ`     | System frequency (usually 60.00)       |

---

## 🔹 1. **Bus Data Section**

```
I, NAME, BASKV, IDE, AREA, ZONE, OWNER, VM, VA, NVHI, NVLO, EVHI, EVLO
```

| Field   | Meaning |
|---------|---------|
| `I`     | Bus number (integer) |
| `NAME`  | Bus name (up to 12 characters) |
| `BASKV` | Base voltage in kilovolts (kV) |
| `IDE`   | Bus type: 1 = Load, 2 = Gen, 3 = Slack, 4 = Isolated |
| `AREA`  | Control area number |
| `ZONE`  | Zone number |
| `OWNER` | Owner number |
| `VM`    | Voltage magnitude (in per unit, p.u.) |
| `VA`    | Voltage angle (in degrees) |
| `NVHI`  | **Normal high voltage limit** (p.u.) – acceptable steady-state upper bound |
| `NVLO`  | **Normal low voltage limit** (p.u.) – acceptable steady-state lower bound |
| `EVHI`  | **Emergency high voltage limit** (p.u.) – upper bound during contingencies |
| `EVLO`  | **Emergency low voltage limit** (p.u.) – lower bound during contingencies |

> All voltage values (`VM`, `NVHI`, `NVLO`, `EVHI`, `EVLO`) are in **per unit (p.u.)**, and all
> angles (`VA`) are in **degrees**.

---

## 🔹 2. **Load Data Section**

```
I, ID, STATUS, AREA, ZONE, PL, QL, IP, IQ, YP, YQ, OWNER
```

| Field   | Description |
|---------|-------------|
| `I`     | Bus number where the load is connected |
| `ID`    | Load ID (2 characters to distinguish multiple loads at the same bus) |
| `STATUS`| Load status (1 = in-service, 0 = out-of-service) |
| `AREA`  | Area number for the load |
| `ZONE`  | Zone number for the load |
| `PL`    | Constant active power load (MW, total 3-phase) |
| `QL`    | Constant reactive power load (MVAr, total 3-phase) |
| `IP`    | Constant current active component (p.u. at 1.0 p.u. voltage) |
| `IQ`    | Constant current reactive component (p.u. at 1.0 p.u. voltage) |
| `YP`    | Constant admittance active component (p.u.) |
| `YQ`    | Constant admittance reactive component (p.u.) |
| `OWNER` | Ownership code |

> All power values are in **MW or MVAr** and represent **3-phase totals**.  
> Current and admittance components are in **per unit (p.u.)**, and apply to voltage-dependent load modeling.

---

## 🔹 3. **Fixed Shunt Data Section**

```
I, ID, STATUS, GL, BL
```

| Field  | Description                                                |
|--------|------------------------------------------------------------|
| `I`    | Bus number where the shunt is connected                    |
| `ID`   | Shunt identifier (2 characters)                            |
| `STATUS` | 1 = in service, 0 = out of service                       |
| `GL`   | Conductance in MW on the system base                       |
| `BL`   | Susceptance in MVAr on the system base                     |

> `GL` and `BL` represent the real and reactive power at a bus voltage of 1.0 p.u. They can be converted to siemens using `V^2` where `V` is the bus base kV.

---

## 🔹 4. **Generator Data Section**
![Generator one line diagram](psse_gen_impedance.png)
```
I, ID, PG, QG, QT, QB, VS, IREG, MBASE, ZR, ZX, RT, XT, GTAP, STAT, RMPCT, PT, PB, O1–O8
```

| Field     | Description |
|-----------|-------------|
| `I`       | Bus number where the generator is connected |
| `ID`      | Generator ID (2 characters, e.g. '1 ') |
| `PG`      | Active power output (MW, total for 3 phases) |
| `QG`      | Reactive power output (MVAr, total for 3 phases) |
| `QT`      | Maximum reactive power limit (MVAr) |
| `QB`      | Minimum reactive power limit (MVAr) |
| `VS`      | Voltage setpoint (p.u.) at regulated bus |
| `IREG`    | Bus number where voltage is regulated |
| `MBASE`   | Generator MVA base |
| `ZR`, `ZX`| Step-up transformer resistance/reactance (p.u.) |
| `RT`, `XT`| Transformer impedance (p.u.) |
| `GTAP`    | Transformer tap ratio |
| `STAT`    | Generator status (1 = in service, 0 = out of service) |
| `RMPCT`   | Participation factor in automatic generation control (AGC) |
| `PT`      | Maximum active power limit (MW) |
| `PB`      | Minimum active power limit (MW) |
| `O1`–`O8` | Ownership identifiers or participation fractions |

> Note: All power values (`PG`, `QG`, `QT`, `QB`, `PT`, `PB`) are in **megawatts (MW)** or **megavars (MVAr)** and represent **3-phase totals**. Impedances are in **per unit (p.u.)** on the specified `MBASE`.

---

## 🔹 5. **Branch Data Section**

```
I, J, CKT, R, X, B, RATEA, RATEB, RATEC, GI, BJ, ST, ANG, LEN, O1–O4
```

| Field     | Description |
|-----------|-------------|
| `I`, `J`  | From and To bus numbers |
| `CKT`     | Circuit ID (2 characters, distinguishes parallel lines) |
| `R`       | Positive-sequence resistance (p.u.) |
| `X`       | Positive-sequence reactance (p.u.) |
| `B`       | Total line charging susceptance (p.u.), split evenly at both ends |
| `RATEA`   | MVA rating A (continuous) |
| `RATEB`   | MVA rating B (long-term emergency) |
| `RATEC`   | MVA rating C (short-term emergency) |
| `GI`, `BJ`| Shunt conductance/admittance at terminals I and J (p.u.) |
| `ST`      | Status (1 = in-service, 0 = out-of-service) |
| `ANG`     | Phase shift angle (degrees), typically 0 for lines |
| `LEN`     | Line length (miles or km; informational only) |
| `O1–O4`   | Ownership fields (IDs or participation fractions) |

> All impedance values (`R`, `X`, `B`) are in **per unit (p.u.)** on the system base MVA.  
> Branches include both transmission lines and transformer equivalents not modeled as detailed multi-winding records.

---

## 🔹 6. **Transformer Data Section**

Transformer records span **4 lines for 2-winding** transformers and **5 lines for 3-winding** transformers.

---

### 🔸 Line 1: Identification and Configuration

```
I, J, K, CKT, CW, CZ, CM, MAG1, MAG2, NMETR, NAME
```

| Field | Description |
|-------|-------------|
| `I`, `J`, `K` | Bus numbers for windings 1, 2, 3 (K=0 for 2-winding) |
| `CKT` | Circuit ID (2 characters) |
| `CW` | Winding data code (1=common, 2=own base, 3=nominal kV) |
| `CZ` | Impedance data code |
| `CM` | Magnetizing admittance code |
| `MAG1`, `MAG2` | Magnetizing admittance (G + jB) in p.u. or % |
| `NMETR` | Metered winding (1, 2, or 3) |
| `NAME` | Transformer name (up to 12 characters) |

---

### 🔸 Line 2: Winding Voltages and Impedances (1-2)

```
WINDV1, NOMV1, ANG1, WINDV2, NOMV2, ANG2, R1-2, X1-2, SBASE1-2
```

| Field | Description |
|-------|-------------|
| `WINDV1` | Voltage setpoint at winding 1 (p.u.) |
| `NOMV1`  | Nominal voltage of winding 1 (kV) |
| `ANG1`   | Phase shift at winding 1 (degrees) |
| `WINDV2` | Voltage setpoint at winding 2 (p.u.) |
| `NOMV2`  | Nominal voltage of winding 2 (kV) |
| `ANG2`   | Phase shift at winding 2 (degrees) |
| `R1-2`   | Series resistance between winding 1–2 (p.u.) |
| `X1-2`   | Series reactance between winding 1–2 (p.u.) |
| `SBASE1-2` | Base MVA for impedance 1–2 |

---

### 🔸 Line 3: Winding 1 Control Data

```
TAP1, CNTR1, RMAX1, RMIN1, STEP1, NTP1
```

| Field | Description |
|-------|-------------|
| `TAP1`  | Initial tap (p.u.) |
| `CNTR1` | Controlled bus or 0 if none |
| `RMAX1`, `RMIN1` | Tap range max/min (p.u.) |
| `STEP1` | Step size |
| `NTP1`  | Number of tap positions |

---

### 🔸 Line 4: Winding 2 Control Data

```
TAP2, CNTR2, RMAX2, RMIN2, STEP2, NTP2
```

(Same fields as Line 3 but for winding 2)

---

### 🔸 Line 5: Winding 3 Data (Only for 3-winding transformers)

```
WINDV3, NOMV3, ANG3, R3-1, X3-1, SBASE3-1, TAP3, CNTR3, RMAX3, RMIN3, STEP3, NTP3
```

---


---

## 🔹 🔍 Transformer Record Example – Updated Breakdown (2-winding)

```
8,    5,    0,'1 ',1,1,1,  0.00000,  0.00000,2,'        ',1,   1,1.0000,   0,1.0000,   0,1.0000,   0,1.0000
0.00000, 0.02670, 100.00
0.98500,  0.000,   0.000,   0.00,   0.00,   0.00,0,     0, 1.50000, 0.51000, 1.50000, 0.51000,159, 0, 0.00000, 0.00000
1.00000,  0.000
```

| Line | Description |
|------|-------------|
| Line 1 | Transformer between buses 8 and 5, codes CW=CZ=CM=1, no magnetizing admittance, metered at winding 2 |
| Line 2 | Impedance R₁₂ = 0.00000, X₁₂ = 0.02670, base = 100 MVA |
| Line 3 | Winding 1: VM = 0.985, ANG = 0.0; regulation off; thermal ratings 1.5 MVA / 0.51; owner = 159 |
| Line 4 | Winding 2: VM = 1.000, ANG = 0.0 |

```
30,   17,    0,'1 ',1,1,1,  0.00000,  0.00000,2,'        ',1,   1,1.0000,   0,1.0000,   0,1.0000,   0,1.0000
0.00000, 0.03880, 100.00
0.96000,  0.000,   0.000,   0.00,   0.00,   0.00,0,     0, 1.50000, 0.51000, 1.50000, 0.51000,159, 0, 0.00000, 0.00000
1.00000,  0.000
```

| Line | Description |
|------|-------------|
| Line 1 | Transformer between buses 30 and 17, identical modeling codes |
| Line 2 | Impedance R₁₂ = 0.00000, X₁₂ = 0.03880, base = 100 MVA |
| Line 3 | Winding 1: VM = 0.960, no regulation, same thermal limits and ownership |
| Line 4 | Winding 2: VM = 1.000, ANG = 0.0 |


---

## 📘 CW – Winding Data Code Summary

The `CW` field appears in **Line 1** of each transformer record and defines how PSS®E interprets **voltage bases** and **impedance bases** for the transformer windings.

| CW | Meaning | Voltage Base | Impedance Base |
|----|---------|---------------|----------------|
| 1  | Common base for all windings | Taken from bus base voltage (`BASKV`) | System base MVA (from header) |
| 2  | Each winding has its own MVA base | From bus base voltage (`BASKV`) | From `SBASE1-2`, `SBASE2-3`, etc. |
| 3  | Each winding uses its own **nominal voltage** and base | From `NOMV1`, `NOMV2`, `NOMV3` | From `SBASE1-2`, `SBASE2-3`, etc. |

> **Note:** When `CW = 1`, `NOMVx` values may be set to `0` and will default to the `BASKV` of the connected buses.
