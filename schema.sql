CREATE TYPE ecnet."when" AS ENUM
   ('Before market open',
    'After market close');
    
CREATE TABLE ecnet.earnings_calendar
(
  act_symbol text NOT NULL,
  date date NOT NULL,
  "when" ecnet."when",
  CONSTRAINT earnings_calendar_act_symbol_fkey FOREIGN KEY (act_symbol)
      REFERENCES nasdaq.symbol (act_symbol) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
);
