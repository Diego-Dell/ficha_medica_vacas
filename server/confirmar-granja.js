import { abrirBase } from './database.js';

const db = abrirBase(process.env.DATABASE_PATH || './vetlink.sqlite');
try {
  const id = process.argv[2];
  if (!id) {
    console.table(db.prepare('SELECT id,nombre,runsa FROM granjas WHERE confirmada=0').all());
  } else {
    const result = db.prepare('UPDATE granjas SET confirmada=1 WHERE id=?').run(id);
    if (!result.changes) throw new Error('Granja no encontrada');
    console.log('Granja confirmada');
  }
} finally { db.close(); }
