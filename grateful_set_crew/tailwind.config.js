/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/grateful_set_crew_web.ex',
    '../lib/grateful_set_crew_web/**/*.*ex',
  ],
  theme: {
    extend: {
      colors: {
        // GratefulSetCrew custom palette
        navy: '#1A3A52',
        gold: '#D4AF37',
        'orange-cta': '#FF6B35',
        'light-bg': '#F0F4F8',

        // Semantic color mapping for application states
        brand: {
          navy: '#1A3A52',
          gold: '#D4AF37',
          orange: '#FF6B35',
          light: '#F0F4F8',
        },
      },
      backgroundColor: {
        primary: '#1A3A52',
        accent: '#FF6B35',
        secondary: '#D4AF37',
      },
      textColor: {
        primary: '#1A3A52',
        accent: '#FF6B35',
        secondary: '#D4AF37',
      },
      borderColor: {
        primary: '#1A3A52',
        accent: '#FF6B35',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
  ],
}
