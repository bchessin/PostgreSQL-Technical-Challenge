BEGIN TRANSACTION;

/* Remove old tables - to prevent "table already exists" error on subsequent runs
   and also to make sure we have up to date data on each trial*/ 
DROP TABLE IF EXISTS actions;
DROP TABLE IF EXISTS users;

/* Create a table called Actions */
CREATE TABLE actions (
    Time TIMESTAMP NOT NULL, 
    User_ID integer NOT NULL, 
    Action_Name CHAR(64) NOT NULL, 
    Terminal CHAR(64) NOT NULL
);

/* Create a table called Users */
CREATE TABLE users (
    User_ID integer NOT NULL, 
    Created TIMESTAMP NOT NULL
);

/* Create few records in Users table (only uses for user creation) */
INSERT INTO users VALUES(1, to_timestamp('02-07-2018', 'mm-dd-yyyy'));
INSERT INTO users VALUES(2, to_timestamp('02-10-2018', 'mm-dd-yyyy'));
INSERT INTO users VALUES(3, to_timestamp('02-11-2018', 'mm-dd-yyyy'));
INSERT INTO users VALUES(4, to_timestamp('02-12-2018', 'mm-dd-yyyy'));
INSERT INTO users VALUES(5, to_timestamp('02-12-2018', 'mm-dd-yyyy'));
SELECT user_id, to_char(created, 'mm-dd-yyyy') as created FROM users;

/* Create few records in Actions table */
INSERT INTO actions VALUES(to_timestamp('02-01-2018', 'mm-dd-yyyy'), 1, 'update', 'iOS');
INSERT INTO actions VALUES(to_timestamp('02-07-2018', 'mm-dd-yyyy'), 2, 'update', 'iOS');
INSERT INTO actions VALUES(to_timestamp('02-10-2018', 'mm-dd-yyyy'), 3, 'OPEN_APP', 'Android');
INSERT INTO actions VALUES(to_timestamp('02-15-2018', 'mm-dd-yyyy'), 3, 'update', 'Android');
INSERT INTO actions VALUES(to_timestamp('02-15-2018', 'mm-dd-yyyy'), 4, 'OPEN_APP', 'iOS');
INSERT INTO actions VALUES(to_timestamp('02-15-2018', 'mm-dd-yyyy'), 5, 'OPEN_APP', 'iOS');
INSERT INTO actions VALUES(to_timestamp('03-06-2018', 'mm-dd-yyyy'), 5, 'OPEN_APP', 'iOS');
SELECT to_char(time, 'mm-dd-yyyy') as time, 
        user_id, 
        action_name, 
        terminal 
        FROM actions;

/* Example SQL Command */
SELECT count (distinct user_id) from actions WHERE time::date = '2018-02-02' and action_name = 'OPEN_APP';

/* Question 1 */
with dau as (
      select time, count(distinct user_id) as dau
      from actions
      group by time
     )
select to_char(time, 'mm-dd-yyyy') as date, dau from dau WHERE time >= '02-01-2018' and time <= '03-01-2018';

/* Question 2 */ 

/* Create all rows in month of February + 7 days */
DROP TABLE IF EXISTS daysq2table;
CREATE TABLE daysq2table AS SELECT to_char(date, 'mm-dd-yyyy') as date
from generate_series(
  '02-01-2018'::date,
  '03-06-2018'::date,
  '1 day'::interval
) date;

/* Generate DAU's for beginning of february to end of february + 7 days (different than previous DAU code in question 1) */
DROP TABLE IF EXISTS dauq2table;
create table dauq2table as 
with dauq2 as (
      select time as date, count(distinct user_id) as dauq2
      from actions
      group by date
     )
select to_char(date, 'mm-dd-yyyy'), dauq2 from dauq2 WHERE date >= '02-01-2018' and date <= '03-06-2018';

/* Doing a join on the DAUs from all of february to march 7 and the days series we just created */
DROP TABLE IF EXISTS q2table;
CREATE TABLE q2table AS SELECT daysq2table.date,
                           dauq2table.to_char as dauDate,
                           COALESCE(dauq2table.dauQ2, 0) as dauQ2   
                            FROM daysq2table FULL JOIN dauq2table ON (daysq2table.date = dauq2table.to_char);
ALTER TABLE q2table DROP COLUMN IF EXISTS daudate;

/* Calculate moving averages for each day */ 
select date, dauq2 as dau, sum(dauq2) over(order by date ROWS BETWEEN 0 preceding AND 6 following) as dau_moving_average
from q2table
order by date;

/* Question 3 */

/* Get incrementing registered users for each day from earliest to latest date from users table */
/* Also will get user retention anytime a distinct user_id does something with action 'OPEN_APP' */
select
    to_char(gs.date, 'mm-dd-yyyy') as date,
    (select count(distinct users.user_id) from users where users.created >= (select MIN(users.created) from users)::date and users.created <= gs.date) as registered_users,
    (select count(distinct actions.user_id) from actions where (actions.action_name = 'OPEN_APP') and (actions.time = gs.date + interval '1' day)) as day_1_retention,
    (select count(distinct actions.user_id) from actions where (actions.action_name = 'OPEN_APP') and (actions.time = gs.date + interval '2' day)) as day_2_retention,
    (select count(distinct actions.user_id) from actions where (actions.action_name = 'OPEN_APP') and (actions.time = gs.date + interval '3' day)) as day_3_retention,
    (select count(distinct actions.user_id) from actions where (actions.action_name = 'OPEN_APP') and (actions.time = gs.date + interval '4' day)) as day_4_retention,
    (select count(distinct actions.user_id) from actions where (actions.action_name = 'OPEN_APP') and (actions.time = gs.date + interval '5' day)) as day_5_retention
from
    generate_series(
    (select MIN(users.created) from users)::date,
    (select MAX(users.created) from users)::date,
        interval '1' day) gs
order by gs.date;


/* Commit the file */ 
COMMIT;
