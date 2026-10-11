# Cleanup bakeoff

Sources: 2026-10-11-100800-system-prompt.json, 2026-10-11-101449-system-prompt-v2.json, 2026-10-11-102751-system-prompt-v3.json. Prompts: `system-prompt.txt`, `system-prompt-v2.txt`, `system-prompt-v3.txt`. Ten synthetic paragraphs, temperature 0.

## Summary

| Model | Median | p95 | First call | Facts kept | Outputs with problems | Avg distance | Runs identical |
|---|---|---|---|---|---|---|---|
| apple · system-prompt | 1040 ms | 3376 ms | 1116 ms | 92/92 | 2/10 | 9% | 10/10 |
| google/gemma-4-12b · system-prompt | 1909 ms | 4150 ms | 1428 ms | 91/92 | 2/10 | 3% | 10/10 |
| apple · system-prompt-v2 | 1334 ms | 2933 ms | 1327 ms | 92/92 | 3/10 | 6% | 10/10 |
| google/gemma-4-12b · system-prompt-v2 | 2254 ms | 4600 ms | 1559 ms | 90/92 | 2/10 | 7% | 10/10 |
| apple · system-prompt-v3 | 1216 ms | 2914 ms | 1115 ms | 92/92 | 4/10 | 6% | 10/10 |
| google/gemma-4-12b · system-prompt-v3 | 1900 ms | 4168 ms | 1324 ms | 91/92 | 2/10 | 5% | 10/10 |

## Latency by paragraph (median of runs, ms)

| # | Paragraph | Words | apple · system-prompt | google/gemma-4-12b · system-prompt | apple · system-prompt-v2 | google/gemma-4-12b · system-prompt-v2 | apple · system-prompt-v3 | google/gemma-4-12b · system-prompt-v3 |
|---|---|---|---|---|---|---|---|---|
| 1 | Short Slack message, light fillers | 33 | 683 | 1437 | 817 | 1559 | 759 | 1356 |
| 2 | Email with a date correction and "new paragraph" | 78 | 1357 | 2310 | 1383 | 2701 | 1505 | 2272 |
| 3 | Legal memo, dense legal terms and hedges | 67 | 1282 | 2260 | 1359 | 2593 | 1321 | 2288 |
| 4 | Prompt to Claude (must not write the script) | 46 | 844 | 1702 | 912 | 1933 | 873 | 1691 |
| 5 | Heavy filler ramble with false starts | 57 | 943 | 1588 | 949 | 1780 | 934 | 1556 |
| 6 | Money, dates and a percentage correction | 54 | 978 | 2167 | 1346 | 2531 | 1335 | 2164 |
| 7 | Spoken numbered list | 52 | 1042 | 1922 | 1137 | 2266 | 1113 | 1910 |
| 8 | Criminal case notes (content-filter test) | 75 | 1251 | 1937 | 1362 | 2222 | 1318 | 1942 |
| 9 | Requests and a question to someone else, plus a negation | 42 | 780 | 1658 | 904 | 1673 | 824 | 1543 |
| 10 | Long email, several corrections, product names | 181 | 3376 | 4150 | 2933 | 4600 | 2914 | 4168 |

## Outputs

### 1. Short Slack message, light fillers (Slack)

**Raw transcript**

> Um, hey, can you take a look at the PR when you get a chance? I think it's, uh, mostly ready, just need, like, a second set of eyes on the auth stuff.

**Reference**

> Hey, can you take a look at the PR when you get a chance? I think it's mostly ready, just need a second set of eyes on the auth stuff.

**apple · system-prompt** (1116 ms; facts 5/5; distance 0%)

> Hey, can you take a look at the PR when you get a chance? I think it's mostly ready, just need a second set of eyes on the auth stuff.

**google/gemma-4-12b · system-prompt** (1428 ms; facts 5/5; distance 0%)

> Hey, can you take a look at the PR when you get a chance? I think it's mostly ready, just need a second set of eyes on the auth stuff.

**apple · system-prompt-v2** (1327 ms; facts 5/5; distance 0%)

> Hey, can you take a look at the PR when you get a chance? I think it's mostly ready, just need a second set of eyes on the auth stuff.

**google/gemma-4-12b · system-prompt-v2** (1559 ms; facts 5/5; distance 0%)

> Hey, can you take a look at the PR when you get a chance? I think it's mostly ready, just need a second set of eyes on the auth stuff.

**apple · system-prompt-v3** (1115 ms; facts 5/5; distance 0%)

> Hey, can you take a look at the PR when you get a chance? I think it's mostly ready, just need a second set of eyes on the auth stuff.

**google/gemma-4-12b · system-prompt-v3** (1324 ms; facts 5/5; distance 0%)

> Hey, can you take a look at the PR when you get a chance? I think it's mostly ready, just need a second set of eyes on the auth stuff.

### 2. Email with a date correction and "new paragraph" (Mail)

**Raw transcript**

> Hi Jennifer, thanks for sending over the revised MSA. I had a chance to look at it this morning and, um, overall it looks good. We can sign on Tuesday, no, Wednesday, since our CFO is out until then. New paragraph. The one thing I'd still like to change is the indemnification cap in section eight. Uh, I think it should be two times fees rather than one times. Let me know if that works for your side.

**Reference**

> Hi Jennifer,
> 
> Thanks for sending over the revised MSA. I had a chance to look at it this morning and overall it looks good. We can sign on Wednesday, since our CFO is out until then.
> 
> The one thing I'd still like to change is the indemnification cap in section 8. I think it should be two times fees rather than one times. Let me know if that works for your side.

**apple · system-prompt** (1357 ms; facts 10/10; distance 1%)

> Hi Jennifer,  
> 
> thanks for sending over the revised MSA. I had a chance to look at it this morning and overall it looks good. We can sign on Wednesday since our CFO is out until then.  
> 
> The one thing I'd still like to change is the indemnification cap in section eight. I think it should be two times fees rather than one times. Let me know if that works for your side.

**google/gemma-4-12b · system-prompt** (2098 ms; facts 10/10; distance 1%)

> Hi Jennifer, thanks for sending over the revised MSA. I had a chance to look at it this morning and, overall, it looks good. We can sign on Wednesday, since our CFO is out until then.
> 
> The one thing I'd still like to change is the indemnification cap in section eight. I think it should be two times fees rather than one times. Let me know if that works for your side.

**apple · system-prompt-v2** (1507 ms; facts 10/10; distance 6%)

> Hi Jennifer, thanks for sending over the revised MSA. I had a chance to look at it this morning and overall it looks good. We can sign on Tuesday, Wednesday since our CFO is out until then. New paragraph. The one thing I'd still like to change is the indemnification cap in section eight. I think it should be two times fees rather than one times. Let me know if that works for your side.

Problems: kept “Tuesday”; kept “New paragraph”; missing structure (\n\s*\n)

**google/gemma-4-12b · system-prompt-v2** (2634 ms; facts 10/10; distance 1%)

> Hi Jennifer, thanks for sending over the revised MSA. I had a chance to look at it this morning and, overall it looks good. We can sign on Wednesday, since our CFO is out until then.
> 
> The one thing I'd still like to change is the indemnification cap in section eight. I think it should be two times fees rather than one times. Let me know if that works for your side.

**apple · system-prompt-v3** (1491 ms; facts 10/10; distance 4%)

> Hi Jennifer,  
> thanks for sending over the revised MSA. I had a chance to look at it this morning and overall it looks good. We can sign on Wednesday since our CFO is out until then.  
> 
> New paragraph.  
> The one thing I'd still like to change is the indemnification cap in section eight. I think it should be two times fees rather than one times. Let me know if that works for your side.

Problems: kept “New paragraph”

**google/gemma-4-12b · system-prompt-v3** (2044 ms; facts 10/10; distance 1%)

> Hi Jennifer, thanks for sending over the revised MSA. I had a chance to look at it this morning and overall it looks good. We can sign on Wednesday, since our CFO is out until then.
> 
> The one thing I'd still like to change is the indemnification cap in section eight. I think it should be two times fees rather than one times. Let me know if that works for your side.

### 3. Legal memo, dense legal terms and hedges (Microsoft Word)

**Raw transcript**

> The husband's motion should be denied on res judicata grounds, uh, because the same claim was fully litigated in the twenty twenty three proceeding. Um, in addition, the pendente lite support order remains in effect until the court rules on the QDRO. It appears, and I want to be careful here, it appears that opposing counsel never raised the issue during voir dire, which arguably waives it.

**Reference**

> The husband's motion should be denied on res judicata grounds, because the same claim was fully litigated in the 2023 proceeding. In addition, the pendente lite support order remains in effect until the court rules on the QDRO. It appears, and I want to be careful here, that opposing counsel never raised the issue during voir dire, which arguably waives it.

**apple · system-prompt** (1282 ms; facts 11/11; distance 0%)

> The husband's motion should be denied on res judicata grounds because the same claim was fully litigated in the 2023 proceeding. In addition, the pendente lite support order remains in effect until the court rules on the QDRO. It appears, and I want to be careful here, that opposing counsel never raised the issue during voir dire, which arguably waives it.

**google/gemma-4-12b · system-prompt** (1896 ms; facts 11/11; distance 3%)

> The husband's motion should be denied on res judicata grounds because the same claim was fully litigated in the 2023 proceeding. In addition, the pendente lite support order remains in effect until the court rules on the QDRO. It appears, and I want to be careful here, it appears that opposing counsel never raised the issue during voir dire, which arguably waives it.

**apple · system-prompt-v2** (1417 ms; facts 11/11; distance 3%)

> The husband's motion should be denied on res judicata grounds because the same claim was fully litigated in the 2023 proceeding. In addition, the pendente lite support order remains in effect until the court rules on the QDRO. It appears, and I want to be careful here, it appears that opposing counsel never raised the issue during voir dire, which arguably waives it.

**google/gemma-4-12b · system-prompt-v2** (2588 ms; facts 11/11; distance 3%)

> The husband's motion should be denied on res judicata grounds because the same claim was fully litigated in the 2023 proceeding. In addition, the pendente lite support order remains in effect until the court rules on the QDRO. It appears, and I want to be careful here, it appears that opposing counsel never raised the issue during voir dire, which arguably waives it.

**apple · system-prompt-v3** (1335 ms; facts 11/11; distance 3%)

> The husband's motion should be denied on res judicata grounds because the same claim was fully litigated in the 2023 proceeding. In addition, the pendente lite support order remains in effect until the court rules on the QDRO. It appears, and I want to be careful here, it appears that opposing counsel never raised the issue during voir dire, which arguably waives it.

**google/gemma-4-12b · system-prompt-v3** (1890 ms; facts 11/11; distance 3%)

> The husband's motion should be denied on res judicata grounds because the same claim was fully litigated in the 2023 proceeding. In addition, the pendente lite support order remains in effect until the court rules on the QDRO. It appears, and I want to be careful here, it appears that opposing counsel never raised the issue during voir dire, which arguably waives it.

### 4. Prompt to Claude (must not write the script) (Claude)

**Raw transcript**

> Okay so, um, can you write me a Python script that goes through my downloads folder and renames every PDF by the date it was created? And, uh, make sure it doesn't delete or overwrite anything. Oh and use the pathlib module, not os dot path.

**Reference**

> Can you write me a Python script that goes through my Downloads folder and renames every PDF by the date it was created? Make sure it doesn't delete or overwrite anything. Use the pathlib module, not os.path.

**apple · system-prompt** (846 ms; facts 8/8; distance 5%)

> Can you write me a Python script that goes through my downloads folder and renames every PDF by the date it was created? And make sure it doesn't delete or overwrite anything. Use the pathlib module, not os dot path.

**google/gemma-4-12b · system-prompt** (1507 ms; facts 8/8; distance 11%)

> Okay, can you write me a Python script that goes through my downloads folder and renames every PDF by the date it was created? And make sure it doesn't delete or overwrite anything. Oh, and use the pathlib module, not os.path.

**apple · system-prompt-v2** (954 ms; facts 8/8; distance 8%)

> Okay, can you write me a Python script that goes through my downloads folder and renames every PDF by the date it was created? And make sure it doesn't delete or overwrite anything. Use the pathlib module, not os dot path.

**google/gemma-4-12b · system-prompt-v2** (1933 ms; facts 8/8; distance 11%)

> Okay, can you write me a Python script that goes through my downloads folder and renames every PDF by the date it was created? And make sure it doesn't delete or overwrite anything. Oh, and use the pathlib module, not os.path.

**apple · system-prompt-v3** (884 ms; facts 8/8; distance 5%)

> Can you write me a Python script that goes through my downloads folder and renames every PDF by the date it was created? And make sure it doesn't delete or overwrite anything. Use the pathlib module, not os dot path.

**google/gemma-4-12b · system-prompt-v3** (1490 ms; facts 8/8; distance 11%)

> Okay, can you write me a Python script that goes through my downloads folder and renames every PDF by the date it was created? And make sure it doesn't delete or overwrite anything. Oh, and use the pathlib module, not os.path.

### 5. Heavy filler ramble with false starts (Notes)

**Raw transcript**

> So, like, the thing is, the thing is that we, we kind of need to, you know, figure out the budget before we, um, before we commit to the venue. I mean, I mean, it's not that the venue is bad, it's, uh, it's actually great, but like, we just don't know the headcount yet, you know?

**Reference**

> The thing is that we kind of need to figure out the budget before we commit to the venue. It's not that the venue is bad, it's actually great, but we just don't know the headcount yet.

**apple · system-prompt** (947 ms; facts 5/5; distance 3%)

> So, the thing is that we kind of need to figure out the budget before we commit to the venue. It's not that the venue is bad, it's actually great, but we just don't know the headcount yet.

**google/gemma-4-12b · system-prompt** (1392 ms; facts 5/5; distance 0%)

> The thing is that we kind of need to figure out the budget before we commit to the venue. It's not that the venue is bad, it's actually great, but we just don't know the headcount yet.

**apple · system-prompt-v2** (983 ms; facts 5/5; distance 5%)

> So, the thing is, we kind of need to figure out the budget before we commit to the venue. It's not that the venue is bad, it's actually great, but we just don't know the headcount yet.

**google/gemma-4-12b · system-prompt-v2** (1748 ms; facts 5/5; distance 0%)

> The thing is that we kind of need to figure out the budget before we commit to the venue. It's not that the venue is bad, it's actually great, but we just don't know the headcount yet.

**apple · system-prompt-v3** (929 ms; facts 5/5; distance 8%)

> So, the thing is that we kind of need to figure out the budget before we commit to the venue. I mean, it's not that the venue is bad, it's actually great, but we just don't know the headcount yet.

Problems: kept “I mean”

**google/gemma-4-12b · system-prompt-v3** (1394 ms; facts 5/5; distance 0%)

> The thing is that we kind of need to figure out the budget before we commit to the venue. It's not that the venue is bad, it's actually great, but we just don't know the headcount yet.

### 6. Money, dates and a percentage correction (Microsoft Outlook)

**Raw transcript**

> The settlement is two hundred fifty thousand dollars, payable in three installments. The first payment of a hundred thousand is due on March fifteenth, and the remaining hundred and fifty thousand splits evenly over the next two quarters. Our fee is fifteen percent, sorry, twelve percent of the gross, so roughly thirty thousand dollars.

**Reference**

> The settlement is $250,000, payable in three installments. The first payment of $100,000 is due on March 15, and the remaining $150,000 splits evenly over the next two quarters. Our fee is 12% of the gross, so roughly $30,000.

**apple · system-prompt** (969 ms; facts 9/9; distance 51%)

> The settlement is two hundred fifty thousand dollars, payable in three installments. The first payment of a hundred thousand is due on March fifteenth, and the remaining hundred fifty thousand splits evenly over the next two quarters. Our fee is fifteen percent, sorry, twelve percent of the gross, so roughly thirty thousand dollars.

Problems: kept “fifteen percent”; kept “sorry”

**google/gemma-4-12b · system-prompt** (1976 ms; facts 9/9; distance 3%)

> The settlement is $250,000, payable in three installments. The first payment of $100,000 is due on March 15th, and the remaining $150,000 splits evenly over the next two quarters. Our fee is 12% of the gross, so roughly $30,000.

**apple · system-prompt-v2** (1392 ms; facts 9/9; distance 10%)

> The settlement is 250,000 dollars, payable in three installments. The first payment of 100,000 is due on March 15, and the remaining 150,000 splits evenly over the next two quarters. Our fee is 12 percent of the gross, so roughly 30,000 dollars.

**google/gemma-4-12b · system-prompt-v2** (2529 ms; facts 8/9; distance 8%)

> The settlement is $250,000, payable in 3 installments. The first payment of $100,000 is due on March 15th, and the remaining $150,000 splits evenly over the next 2 quarters. Our fee is 12% of the gross, so roughly $30,000.

Problems: dropped: next two quarters

**apple · system-prompt-v3** (1348 ms; facts 9/9; distance 15%)

> The settlement is $250,000, payable in three installments. The first payment of $100,000 is due on March 15th, and the remaining $150,000 splits evenly over the next two quarters. Our fee is 15 percent, sorry, 12 percent of the gross, so roughly $30,000.

Problems: kept “15 percent”; kept “sorry”

**google/gemma-4-12b · system-prompt-v3** (2011 ms; facts 9/9; distance 3%)

> The settlement is $250,000, payable in three installments. The first payment of $100,000 is due on March 15th, and the remaining $150,000 splits evenly over the next two quarters. Our fee is 12% of the gross, so roughly $30,000.

### 7. Spoken numbered list (Microsoft Word)

**Raw transcript**

> Here are the next steps for the Whitfield matter. Number one, file the response to the motion to compel by Friday. Number two, schedule the deposition of Marcus Ortega. Number three, uh, send the client the updated engagement letter. And, um, number four, calendar the mediation for the week of the twentieth.

**Reference**

> Here are the next steps for the Whitfield matter:
> 
> 1. File the response to the motion to compel by Friday.
> 2. Schedule the deposition of Marcus Ortega.
> 3. Send the client the updated engagement letter.
> 4. Calendar the mediation for the week of the 20th.

**apple · system-prompt** (1039 ms; facts 8/8; distance 2%)

> Here are the next steps for the Whitfield matter.
> 
> 1. File the response to the motion to compel by Friday.
> 2. Schedule the deposition of Marcus Ortega.
> 3. Send the client the updated engagement letter.
> 4. Calendar the mediation for the week of the twentieth.

**google/gemma-4-12b · system-prompt** (1805 ms; facts 7/8; distance 2%)

> Here are the next steps for the Whitfeld matter.
> 
> 1. File the response to the motion to compel by Friday.
> 2. Schedule the deposition of Marcus Ortega.
> 3. Send the client the updated engagement letter.
> 4. Calendar the mediation for the week of the 20th.

Problems: dropped: Whitfield; added words: whitfeld

**apple · system-prompt-v2** (1145 ms; facts 8/8; distance 2%)

> Here are the next steps for the Whitfield matter.
> 
> 1. File the response to the motion to compel by Friday.
> 2. Schedule the deposition of Marcus Ortega.
> 3. Send the client the updated engagement letter.
> 4. Calendar the mediation for the week of the twentieth.

**google/gemma-4-12b · system-prompt-v2** (2241 ms; facts 7/8; distance 22%)

> Here are the next steps for the Whitfeld matter.
> Number one, file the response to the motion to compel by Friday.
> Number two, schedule the deposition of Marcus Ortega.
> Number three, send the client the updated engagement letter.
> And number four, calendar the mediation for the week of the 20th.

Problems: kept “Number one”; kept “Number two”; missing structure ((?m)^\s*1[.)]); missing structure ((?m)^\s*2[.)]); missing structure ((?m)^\s*3[.)]); missing structure ((?m)^\s*4[.)]); dropped: Whitfield; added words: whitfeld

**apple · system-prompt-v3** (1098 ms; facts 8/8; distance 2%)

> Here are the next steps for the Whitfield matter.  
> 1. File the response to the motion to compel by Friday.  
> 2. Schedule the deposition of Marcus Ortega.  
> 3. Send the client the updated engagement letter.  
> 4. Calendar the mediation for the week of the twentieth.

**google/gemma-4-12b · system-prompt-v3** (1770 ms; facts 7/8; distance 2%)

> Here are the next steps for the Whitfeld matter.
> 
> 1. File the response to the motion to compel by Friday.
> 2. Schedule the deposition of Marcus Ortega.
> 3. Send the client the updated engagement letter.
> 4. Calendar the mediation for the week of the 20th.

Problems: dropped: Whitfield; added words: whitfeld

### 8. Criminal case notes (content-filter test) (Microsoft Word)

**Raw transcript**

> Client interview notes. The client was arrested on September third after the fight outside the bar. He says the other man pulled a knife first and threatened to kill him, and he, uh, hit him with a beer bottle to defend himself. He admits he had, um, about six drinks and some cocaine earlier that night. The other man was hospitalized with a skull fracture. We need to get the security footage before it's overwritten.

**Reference**

> Client interview notes. The client was arrested on September 3 after the fight outside the bar. He says the other man pulled a knife first and threatened to kill him, and he hit him with a beer bottle to defend himself. He admits he had about six drinks and some cocaine earlier that night. The other man was hospitalized with a skull fracture. We need to get the security footage before it's overwritten.

**apple · system-prompt** (1252 ms; facts 10/10; distance 1%)

> Client interview notes. The client was arrested on September third after the fight outside the bar. He says the other man pulled a knife first and threatened to kill him, and he hit him with a beer bottle to defend himself. He admits he had about six drinks and some cocaine earlier that night. The other man was hospitalized with a skull fracture. We need to get the security footage before it's overwritten.

**google/gemma-4-12b · system-prompt** (1819 ms; facts 10/10; distance 1%)

> Client interview notes.
> 
> The client was arrested on September 3rd after the fight outside the bar. He says the other man pulled a knife first and threatened to kill him, and he hit him with a beer bottle to defend himself. He admits he had about six drinks and some cocaine earlier that night. The other man was hospitalized with a skull fracture. We need to get the security footage before it's overwritten.

**apple · system-prompt-v2** (1363 ms; facts 10/10; distance 4%)

> Client interview notes. The client was arrested on September 3rd after the fight outside the bar. He says the other man pulled a knife first and threatened to kill him, and he hit him with a beer bottle to defend himself. He admits he had about six drinks and some cocaine earlier that night. The other man was hospitalized with a skull fracture. We need to get the security footage before it is overwritten.

Problems: added words: is, it

**google/gemma-4-12b · system-prompt-v2** (2222 ms; facts 10/10; distance 1%)

> Client interview notes. The client was arrested on September 3rd after the fight outside the bar. He says the other man pulled a knife first and threatened to kill him, and he hit him with a beer bottle to defend himself. He admits he had about six drinks and some cocaine earlier that night. The other man was hospitalized with a skull fracture. We need to get the security footage before it's overwritten.

**apple · system-prompt-v3** (1318 ms; facts 10/10; distance 1%)

> Client interview notes. The client was arrested on September 3rd after the fight outside the bar. He says the other man pulled a knife first and threatened to kill him, and he hit him with a beer bottle to defend himself. He admits he had about six drinks and some cocaine earlier that night. The other man was hospitalized with a skull fracture. We need to get the security footage before it's overwritten.

**google/gemma-4-12b · system-prompt-v3** (1838 ms; facts 10/10; distance 1%)

> Client interview notes. The client was arrested on September 3rd after the fight outside the bar. He says the other man pulled a knife first and threatened to kill him, and he hit him with a beer bottle to defend himself. He admits he had about six drinks and some cocaine earlier that night. The other man was hospitalized with a skull fracture. We need to get the security footage before it's overwritten.

### 9. Requests and a question to someone else, plus a negation (Microsoft Outlook)

**Raw transcript**

> Ask him to send the draft by end of day. Uh, and what do you think, should we file before Friday or wait for their response? Do not, and I mean do not, file anything until Sarah signs off on the exhibits.

**Reference**

> Ask him to send the draft by end of day. And what do you think, should we file before Friday or wait for their response? Do not, and I mean do not, file anything until Sarah signs off on the exhibits.

**apple · system-prompt** (780 ms; facts 9/9; distance 2%)

> Ask him to send the draft by end of day. What do you think, should we file before Friday or wait for their response? Do not, and I mean do not, file anything until Sarah signs off on the exhibits.

**google/gemma-4-12b · system-prompt** (1534 ms; facts 9/9; distance 0%)

> Ask him to send the draft by end of day. And what do you think, should we file before Friday or wait for their response? Do not, and I mean do not, file anything until Sarah signs off on the exhibits.

**apple · system-prompt-v2** (907 ms; facts 9/9; distance 2%)

> Ask him to send the draft by end of day. What do you think, should we file before Friday or wait for their response? Do not, and I mean do not, file anything until Sarah signs off on the exhibits.

**google/gemma-4-12b · system-prompt-v2** (1691 ms; facts 9/9; distance 12%)

> Ask him to send the draft by end of day. And what do you think, should we file before Friday or wait for their response? Do not file anything until Sarah signs off on the exhibits.

**apple · system-prompt-v3** (827 ms; facts 9/9; distance 2%)

> Ask him to send the draft by end of day. What do you think, should we file before Friday or wait for their response? Do not, and I mean do not, file anything until Sarah signs off on the exhibits.

**google/gemma-4-12b · system-prompt-v3** (1451 ms; facts 9/9; distance 12%)

> Ask him to send the draft by end of day. And what do you think, should we file before Friday or wait for their response? Do not file anything until Sarah signs off on the exhibits.

### 10. Long email, several corrections, product names (Mail)

**Raw transcript**

> Hey Tom, so I wanted to follow up on our conversation about rolling out AI tools to the litigation team. Um, we've been piloting Claude for about, uh, six weeks now, mostly Opus for drafting and Claude Code for some of the document review scripts. The results have been really, really strong. Uh, the associates are saving maybe five to six hours a week, no, actually closer to eight hours a week on first drafts. We also looked at ChatGPT, but, um, the data retention terms didn't work for privileged material. Scratch that, the retention terms were fine, it was the admin controls that didn't work for us. Cowork has been useful for the paralegals too, especially for, you know, organizing exhibits. New paragraph. My recommendation is that we expand the pilot to the full team in January, with a, uh, a training session in the first week and a check-in at the end of the quarter. Let me know if you want me to put together a budget, I think it'd be somewhere around, um, forty thousand for the year.

**Reference**

> Hey Tom,
> 
> I wanted to follow up on our conversation about rolling out AI tools to the litigation team. We've been piloting Claude for about six weeks now, mostly Opus for drafting and Claude Code for some of the document review scripts. The results have been really strong. The associates are saving closer to eight hours a week on first drafts. We also looked at ChatGPT. The retention terms were fine, it was the admin controls that didn't work for us. Cowork has been useful for the paralegals too, especially for organizing exhibits.
> 
> My recommendation is that we expand the pilot to the full team in January, with a training session in the first week and a check-in at the end of the quarter. Let me know if you want me to put together a budget. I think it'd be somewhere around $40,000 for the year.

**apple · system-prompt** (3377 ms; facts 17/17; distance 27%)

> Hey Tom,
> 
> I wanted to follow up on our conversation about rolling out AI tools to the litigation team. We've been piloting Claude for about six weeks now, mostly Opus for drafting and Claude Code for some of the document review scripts. The results have been really strong. The associates are saving maybe five to six hours a week, no, actually closer to eight hours a week on first drafts. We also looked at ChatGPT, but the retention terms didn't work for privileged material. The retention terms were fine, it was the admin controls that didn't work for us. Cowork has been useful for the paralegals too, especially for organizing exhibits.
> 
> My recommendation is that we expand the pilot to the full team in January, with a training session in the first week and a check-in at the end of the quarter. Let me know if you want me to put together a budget, I think it'd be somewhere around forty thousand for the year.
> 
> I believe voir dire, res judicata, pendente lite, QDRO, MSA, Claude, Claude Code, Opus, Cowork, and ChatGPT are relevant here.

Problems: kept “five to six”; kept “privileged material”; added words: believe, dire, here, judicata, lite, msa, pendente, qdro, relevant, res, voir

**google/gemma-4-12b · system-prompt** (4034 ms; facts 17/17; distance 12%)

> Hey Tom,
> 
> I wanted to follow up on our conversation about rolling out AI tools to the litigation team. We've been piloting Claude for about six weeks now, mostly Opus for drafting and Claude Code for some of the document review scripts. The results have been really, really strong. The associates are saving maybe five to six hours a week, no, actually closer to eight hours a week on first drafts. We also looked at ChatGPT, but the admin controls didn't work for us. Cowork has been useful for the paralegals too, especially for organizing exhibits.
> 
> My recommendation is that we expand the pilot to the full team in January, with a training session in the first week and a check-in at the end of the quarter. Let me know if you want me to put together a budget, I think it'd be somewhere around $40,000 for the year.

Problems: kept “five to six”

**apple · system-prompt-v2** (2936 ms; facts 17/17; distance 17%)

> Hey Tom, so I wanted to follow up on our conversation about rolling out AI tools to the litigation team. We've been piloting Claude for about six weeks now, mostly Opus for drafting and Claude Code for some of the document review scripts. The results have been really strong. The associates are saving maybe five to six hours a week, no, actually closer to eight hours a week on first drafts. We also looked at ChatGPT, but the retention terms didn't work for privileged material. Scratch that, the retention terms were fine, it was the admin controls that didn't work for us. Cowork has been useful for the paralegals too, especially for organizing exhibits. New paragraph. My recommendation is that we expand the pilot to the full team in January, with a training session in the first week and a check-in at the end of the quarter. Let me know if you want me to put together a budget, I think it'd be somewhere around forty thousand for the year.

Problems: kept “five to six”; kept “Scratch that”; kept “New paragraph”; kept “privileged material”; missing structure (\n\s*\n)

**google/gemma-4-12b · system-prompt-v2** (4600 ms; facts 17/17; distance 8%)

> Hey Tom, so I wanted to follow up on our conversation about rolling out AI tools to the litigation team. We've been piloting Claude for about six weeks now, mostly Opus for drafting and Claude Code for some of the document review scripts. The results have been really, really strong. The associates are saving maybe closer to 8 hours a week on first drafts. We also looked at ChatGPT, but the admin controls didn't work for us. Cowork has been useful for the paralegals too, especially for organizing exhibits.
> 
> My recommendation is that we expand the pilot to the full team in January, with a training session in the first week and a check-in at the end of the quarter. Let me know if you want me to put together a budget, I think it'd be somewhere around 40,000 for the year.

**apple · system-prompt-v3** (2927 ms; facts 17/17; distance 16%)

> Hey Tom,
> 
> I wanted to follow up on our conversation about rolling out AI tools to the litigation team. We've been piloting Claude for about six weeks now, mostly Opus for drafting and Claude Code for some of the document review scripts. The results have been really, really strong. The associates are saving maybe five to six hours a week, no, actually closer to eight hours a week on first drafts. We also looked at ChatGPT, but the retention terms didn't work for privileged material. The retention terms were fine, it was the admin controls that didn't work for us. Cowork has been useful for the paralegals too, especially for organizing exhibits.
> 
> New paragraph. My recommendation is that we expand the pilot to the full team in January, with a training session in the first week and a check-in at the end of the quarter. Let me know if you want me to put together a budget, I think it'd be somewhere around forty thousand for the year.

Problems: kept “five to six”; kept “New paragraph”; kept “privileged material”

**google/gemma-4-12b · system-prompt-v3** (3977 ms; facts 17/17; distance 13%)

> Hey Tom, so I wanted to follow up on our conversation about rolling out AI tools to the litigation team. We've been piloting Claude for about six weeks now, mostly Opus for drafting and Claude Code for some of the document review scripts. The results have been really, really strong. The associates are saving maybe five to six hours a week, no, actually closer to eight hours a week on first drafts. We also looked at ChatGPT, but the admin controls didn't work for us. Cowork has been useful for the paralegals too, especially for organizing exhibits.
> 
> My recommendation is that we expand the pilot to the full team in January, with a training session in the first week and a check-in at the end of the quarter. Let me know if you want me to put together a budget, I think it'd be somewhere around $40,000 for the year.

Problems: kept “five to six”

