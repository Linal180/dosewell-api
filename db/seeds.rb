DEMO_PASSWORD = "Password1!"

def demo_user(email:, name:, role:, timezone:)
  user = User.find_or_initialize_by(email:)
  user.name = name
  user.role = role
  user.timezone = timezone
  user.password = DEMO_PASSWORD
  user.save!
  user
end

maya = demo_user(email: "maya.chen@dosewell.test", name: "Maya Chen", role: "doctor", timezone: "America/New_York")
ava = demo_user(email: "ava.shah@dosewell.test", name: "Ava Shah", role: "patient", timezone: "America/New_York")
demo_user(email: "sam.okonkwo@dosewell.test", name: "Sam Okonkwo", role: "patient", timezone: "America/Los_Angeles")
demo_user(email: "priya.nair@dosewell.test", name: "Priya Nair", role: "pharmacist", timezone: "America/Chicago")

[
  ["Lisinopril", "Lisinopril", "lisinopril", "10 mg", "tablet"],
  ["Ibuprofen", "Ibuprofen", "ibuprofen", "200 mg", "tablet"],
  ["Warfarin", "Warfarin", "warfarin", "5 mg", "tablet"],
  ["Aspirin", "Aspirin", "aspirin", "81 mg", "tablet"],
  ["Metformin", "Metformin", "metformin", "500 mg", "tablet"],
  ["Amoxicillin", "Amoxicillin", "amoxicillin", "500 mg", "capsule"],
  ["Atorvastatin", "Atorvastatin", "atorvastatin", "20 mg", "tablet"],
  ["Sertraline", "Sertraline", "sertraline", "50 mg", "tablet"],
  ["Omeprazole", "Omeprazole", "omeprazole", "20 mg", "capsule"],
  ["Albuterol", "Albuterol", "albuterol", "90 mcg", "inhaler"]
].each do |name, generic_name, ingredient, strength, form|
  medication = Medication.find_or_initialize_by(name:, strength:)
  medication.update!(generic_name:, ingredient:, form:)
end

[
  %w[lisinopril ibuprofen moderate],
  %w[ibuprofen warfarin major],
  %w[ibuprofen aspirin moderate],
  %w[warfarin aspirin major],
  %w[aspirin sertraline moderate],
  %w[atorvastatin omeprazole minor]
].each do |left, right, severity|
  descriptions = {
    "major" => "Increased bleeding risk. Do not combine.",
    "moderate" => "Effects can overlap. Confirm before prescribing.",
    "minor" => "Small exposure change. No extra confirmation required."
  }
  pair = [Medication.find_by!(ingredient: left), Medication.find_by!(ingredient: right)]
  low, high = pair.sort_by(&:id)
  interaction = Interaction.find_or_initialize_by(medication_a: low, medication_b: high)
  interaction.update!(severity:, description: "#{low.name} + #{high.name}: #{descriptions.fetch(severity)}")
end

%w[ibuprofen amoxicillin].each do |ingredient|
  Allergy.find_or_create_by!(patient: ava, ingredient:)
end

if ava.prescriptions_as_patient.none?
  today = TZInfo::Timezone.get(ava.timezone).now.to_date
  lisinopril = Medication.find_by!(ingredient: "lisinopril")
  result = Prescriptions::Creator.call(
    doctor: maya,
    params: {
      patient_id: ava.id,
      medication_id: lisinopril.id,
      dose_quantity: 1,
      dose_unit: "tablet",
      frequency: "once_daily",
      times_of_day: ["08:00"],
      duration_days: 10,
      start_date: today - 3,
      timezone: ava.timezone,
      acknowledge_warnings: false
    }
  )
  raise result.prescription.errors.full_messages.join(", ") unless result.ok?

  result.prescription.doses.where(scheduled_at: ..Time.current).order(:scheduled_at).each_with_index do |dose, index|
    recorded = Doses::Recorder.call(dose:, actor: ava, status: index.even? ? "taken" : "missed")
    raise recorded.error unless recorded.ok?
  end
end
