from pathlib import Path
import nbformat as nbf

NOTEBOOK = Path("analysis_results/outer_rotor_radial_vs_3seg_halbach_comprehensive_report.ipynb")
MARKER = "### 8.2 백아이언 경량화와 관성 효과"

nb = nbf.read(NOTEBOOK, as_version=4)
nb.cells = [c for c in nb.cells if not (c.cell_type == "markdown" and MARKER in c.source)]

# Remove the code cell belonging to an older copy of this inserted section.
for i in range(len(nb.cells) - 1, -1, -1):
    if nb.cells[i].cell_type == "code" and "back_iron_mechanical_summary" in nb.cells[i].source:
        del nb.cells[i]

insert_at = next(i for i, c in enumerate(nb.cells)
                 if c.cell_type == "markdown" and c.source.startswith("## 9. 종합 설계 판단"))

markdown = nbf.v4.new_markdown_cell(r"""### 8.2 백아이언 경량화와 관성 효과

전자기적 두께 후보가 실제 회전자 경량화에 주는 효과를 계산했다. 강판 밀도 7,650 kg/m³, 적층길이 150 mm, 백아이언 내반경 70 mm의 원통형 링으로 가정했다. 질량과 극관성모멘트는 **백아이언만의 값**이며 자석, 슬리브, 허브와 축은 포함하지 않는다.

$$m=\rho\pi L(R_o^2-R_i^2),\qquad J_p=\frac{1}{2}m(R_o^2+R_i^2)$$

정격 및 최대 RPM은 이 정자계 결과만으로 결정하지 않는다. 후속 단계에서 역기전력·인버터 전압 제한, 철손·열 및 최대속도 원심응력을 결합해 산정해야 한다.""")

code = nbf.v4.new_code_cell(r"""steel_density = 7650.0       # kg/m^3
stack_length_m = 0.150
back_iron_inner_radius_m = 0.070

candidate_torque = {
    "Radial 5.00 mm": maps["Radial"].query("current_peak_A == 50").torque_Nm.mean(),
    "Radial 3.75 mm": yoke_validation_summary.query("Design == 'Radial' and `Yoke thickness (mm)` == 3.75")["Mean torque (N·m)"].iloc[0],
    "Radial 4.00 mm": yoke_validation_summary.query("Design == 'Radial' and `Yoke thickness (mm)` == 4.00")["Mean torque (N·m)"].iloc[0],
    "Halbach 2.50 mm": yoke_validation_summary.query("Design == '3-seg Halbach' and `Yoke thickness (mm)` == 2.50")["Mean torque (N·m)"].iloc[0],
    "Halbach 2.75 mm": yoke_validation_summary.query("Design == '3-seg Halbach' and `Yoke thickness (mm)` == 2.75")["Mean torque (N·m)"].iloc[0],
}
candidate_thickness = {name: float(name.split()[-2]) for name in candidate_torque}

rows = []
for name, torque in candidate_torque.items():
    thickness_m = candidate_thickness[name] / 1000
    outer_radius = back_iron_inner_radius_m + thickness_m
    mass = steel_density*np.pi*stack_length_m*(outer_radius**2-back_iron_inner_radius_m**2)
    inertia = 0.5*mass*(outer_radius**2+back_iron_inner_radius_m**2)
    rows.append({"Candidate": name, "Back-iron thickness (mm)": 1000*thickness_m,
                 "Rotor OD (mm)": 2000*outer_radius, "Back-iron mass (kg)": mass,
                 "Back-iron polar inertia (kg·m²)": inertia, "Mean torque (N·m)": torque,
                 "Torque/back-iron mass (N·m/kg)": torque/mass})

back_iron_mechanical_summary = pd.DataFrame(rows).set_index("Candidate")
baseline = back_iron_mechanical_summary.loc["Radial 5.00 mm"]
back_iron_mechanical_summary["Mass reduction vs Radial 5 mm (%)"] = 100*(1-back_iron_mechanical_summary["Back-iron mass (kg)"]/baseline["Back-iron mass (kg)"])
back_iron_mechanical_summary["Inertia reduction vs Radial 5 mm (%)"] = 100*(1-back_iron_mechanical_summary["Back-iron polar inertia (kg·m²)"]/baseline["Back-iron polar inertia (kg·m²)"])
back_iron_mechanical_summary["Torque change vs Radial 5 mm (%)"] = 100*(back_iron_mechanical_summary["Mean torque (N·m)"]/baseline["Mean torque (N·m)"]-1)
display(back_iron_mechanical_summary.style.format("{:.3f}"))

plot_rows = back_iron_mechanical_summary.drop(index="Radial 5.00 mm")
fig, axes = plt.subplots(1, 3, figsize=(14, 4.1), constrained_layout=True)
axes[0].bar(plot_rows.index, plot_rows["Mass reduction vs Radial 5 mm (%)"])
axes[1].bar(plot_rows.index, plot_rows["Inertia reduction vs Radial 5 mm (%)"])
axes[2].bar(plot_rows.index, plot_rows["Torque change vs Radial 5 mm (%)"])
axes[0].set(title="Back-iron mass reduction", ylabel="Reduction vs Radial 5 mm (%)")
axes[1].set(title="Back-iron polar-inertia reduction", ylabel="Reduction vs Radial 5 mm (%)")
axes[2].set(title="Mean-torque change", ylabel="Change vs Radial 5 mm (%)")
for ax in axes:
    ax.tick_params(axis="x", rotation=25); ax.grid(axis="y", alpha=.25)
plt.show()""")

conclusion = nbf.v4.new_markdown_cell(r"""Halbach 2.50 mm는 Radial 5.00 mm보다 백아이언 질량이 **50.9%**, 백아이언 극관성이 **52.6%** 감소하면서 평균토크는 **3.61% 높다**. 보수적인 Halbach 2.75 mm도 질량 45.9%, 관성 47.6%를 줄이면서 평균토크는 약 3.65% 높다.

이는 Halbach의 낮은 백아이언 자속을 단순 포화 여유가 아니라 회전자 철 질량·외경·관성 저감으로 전환할 수 있음을 보여준다. 단, 전체 회전자 관성은 자석·슬리브·허브를 포함한 구조 모델에서 다시 계산해야 한다.""")

nb.cells[insert_at:insert_at] = [markdown, code, conclusion]
nbf.write(nb, NOTEBOOK)
print(NOTEBOOK.resolve())
