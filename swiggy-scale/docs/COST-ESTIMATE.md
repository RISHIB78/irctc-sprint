# COST ESTIMATE — AWS Baseline and Peak

## Assumptions
- Currency: USD for AWS rates; convert to INR where noted. Use on-demand prices (approximate public rates).
- Month hours: 720

## Baseline architecture (monthly)

1) EC2: Node.js app servers — t3.medium × 4
- Rate: $0.0416/hr each → 0.0416 × 4 × 720 = $119.81/mo

2) RDS: PostgreSQL primary — db.r6g.large
- Rate: $0.182/hr → 0.182 × 720 = $131.04/mo

3) RDS: Read replicas ×2 (db.r6g.large)
- Rate: $0.182 × 2 × 720 = $262.08/mo

4) ElastiCache Redis cluster ×3 (cache.r6g.large)
- Rate: $0.166/hr × 3 × 720 = $358.56/mo

5) ALB (base + LCU)
- Estimate: $56.20/mo

6) CloudFront (10 TB/mo transfer)
- $0.0085/GB × 10,000 GB = $85.00/mo

7) SQS (1M messages/day × 30 days)
- 30M messages × $0.40/million = $12.00/mo

**Baseline total ≈ $1,024/mo**

## Peak event cost (World Cup night, 4 hours extra)

1) EC2 scaled: t3.2xlarge × 20 for 4 hours
- Rate: $0.3328/hr × 20 × 4 = $26.62

2) Temporary RDS scale up: db.r6g.4xlarge × 4 hours
- Rate: $1.027/hr × 4 = $4.11

3) CloudFront surge: extra 50 TB transfer
- 50,000 GB × $0.0085 = $425.00

**Peak extra ≈ $455 for 4 hours**

## Business comparison
- Estimated loss in 45-minute outage: ₹4.2 crore/minute × 45 = ₹189 crore (~$22.8M at 1 USD = ₹83)
- Monthly baseline cost (~$1k) and event peak (~$455) are negligible compared to outage losses.
