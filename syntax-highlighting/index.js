import express from 'express';
import { common, createStarryNight } from '@wooorm/starry-night';


const start = async () => {
  const starryNight = await createStarryNight(common);

  const app = express();

  const jsonParser = express.json();

  app.post('/highlight', jsonParser, (req, res) => {
    const { language, code } = req.body;
    const scope = starryNight.flagToScope(language);
    const highlightedCode = starryNight.highlight(code, scope);
    res.status(200).send(JSON.stringify({ highlightedCode }));
  });

  app.listen(9002, () => {
    console.log('Server is listening on port 9002');
  });
};

start();
