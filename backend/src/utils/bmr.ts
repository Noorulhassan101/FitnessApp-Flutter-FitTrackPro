export function calculateBMR(
  gender: string,
  age: number,
  heightCm: number,
  weightKg: number
): number {
  const genderLower = gender.toLowerCase();
  
  if (genderLower === 'male' || genderLower === 'm') {
    return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
  } else if (genderLower === 'female' || genderLower === 'f') {
    return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
  } else {
    // Average baseline for other/non-binary
    return 10 * weightKg + 6.25 * heightCm - 5 * age - 78;
  }
}
