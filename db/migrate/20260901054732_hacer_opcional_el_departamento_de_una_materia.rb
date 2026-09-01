# El departamento de una materia pasa a ser OPCIONAL.
#
# El plan de puesta en marcha ya decía —desde MOR-154— que «un colegio chico
# puede vivir sin ellos», y el paso está marcado `opcional: true`. El modelo
# decía lo contrario: `belongs_to :department` sin `optional`, con la columna
# `NOT NULL` debajo.
#
# La consecuencia la encontró Daniel en el QA: un colegio recién registrado
# entra al paso 3 —«Las materias del colegio»—, llena código y nombre, guarda, y
# recibe **«Departamento debe existir»**. Para seguir tiene que irse al paso 8,
# que la app le presentó como opcional. La puesta en marcha se traba en el tercer
# paso de ocho.
#
# ⚠️ El `school_id` de la materia SE DERIVABA del departamento. Sin departamento
# no hay de dónde derivarlo, así que ahora cae en `Current.school` — ver
# `DerivesSchoolFrom#or_from_session`. La columna sigue siendo `NOT NULL`: una
# materia sin colegio no la vería nadie, porque el RLS filtra por ahí.
class HacerOpcionalElDepartamentoDeUnaMateria < ActiveRecord::Migration[8.1]
  def change
    change_column_null :subjects, :department_id, true
  end
end
